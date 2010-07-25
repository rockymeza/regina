class Regina
  VERSION = '0.0.1'
  
  SPECIAL_NAMES = { 
    :dry_run => :n }

  META = %w(title version copyright)
  METAS = %w(author usage)
    
  attr_reader :options
  attr_reader :subcommand
  attr_reader :argv
  attr_reader :flags
  
  def self.next_flag
    if ARGV[0] && ARGV[0][0] == '-'
      return ARGV.shift
    end
  end
  
  def self.next_arg
    if ARGV[0] && ARGV[0][0] != '-'
      return ARGV.shift
    end
  end

  def initialize( *a, &b )
    @meta = {}
    META.each do |meta|
      add_meta meta, nil
    end
    METAS.each do |meta|
      add_meta meta, [] # set it to an empty array
    end
    
    @options = {}
    @commands = {}
    @flags = FlagContainer.new
    @argv = []
    @subcommand = nil
    
    @self = eval 'self', b.binding
    self.instance_eval &b
    
    METAS.each do |meta|
      @meta[meta.to_sym].flatten!
    end
    
    check_commands if ! @commands.empty?
    parse_flags until ARGV.empty?
  end
    
    
  def main
    if @subcommand
      @self.send @subcommand
    else
      help
    end
  end

  
  # provides hash access for options
  def []( key )
    @options[key.to_s]
  end
  

  def add_meta( key, value )
    @meta[key.to_sym] = value
  end


  def add_metas( key, value )
    @meta[key.to_sym] << value
  end

  
  def check_commands
    if @commands.has_key?(ARGV[0])
      @subcommand = Regina.next_arg
    end
  end
    
    
  def parse_flags
    if argv = Regina.next_flag
      if argv.match( /^-h|--help$/ )
        help
      elsif arg = argv.match( /^--([a-z0-9]+)(?:=(.*?))?$/i ) # two dashes
        return set_option arg if @flags.has_key?( arg[1] )
      elsif arg = argv.match( /^-([a-z0-9])(?:=(.*?))?$/i ) # single dash
        return set_option arg if @flags.has_key?( arg[1] )
      elsif arg = argv.match( /^-([a-z0-9]+$)/i )
        options = []
        arg[1].each_char do |c|
          if @flags.has_key?( c )
            options << c
          else
            warning "What do you want me to do with '#{arg}'?"
            return
          end
        end
        if options
          options.each { |c| set_option c}
          return
        end
      end
    else
      return @argv << Regina.next_arg
    end
    warning "What do you want me to do with '#{arg}'?"
  end
    
    
  def set_option( arg )
    if arg.is_a? MatchData
      flag_name, value = arg[1], arg[2]
    elsif arg.is_a? Array
      flag_name = arg[0], arg[1]
    else
      flag_name = arg
    end
    
    flag = @flags[ flag_name ]
    @options[ flag.long_name ] = flag.set( value )
  end
  
  
  def add_option( type, long_name, description, options = {})
    options[:description] = description
    options[:short_name] ||= shorten_name( long_name )
    
    @flags.add( Flag.new( type, long_name, options ) )
    
    # this is sort of odd
    if options[:default]
      @options[ long_name ] = @flags[ long_name ].set_default( options[:default] )
    end
  end
   

  def command( long_name, description, options = {}, &block )
    options[:description] = description
    options[:block] = block
    
    @commands[ long_name ] = options
  end
  alias :sub :command
 
  
  def shorten_name(long_name)
    short_name = SPECIAL_NAMES[ long_name ] ||
                 @flags.uniq?( long_name[0] ) ||
                 @flags.uniq?( long_name[0].capitalize )
    
    short_name || error( 'Could not determine short_name for option: #{long_name}.  Please specify one.' )
  end
  
  
  def help
    message = <<-EOS
#{@meta[:title]}

Usage:
\t#{@meta[:usage].join("\n\t")}
#{@flags.output_options}
#{output_commands}
EOS
    puts message
    exit
  end

  
  def output_commands
    output = "\nCommands:\n"
    @commands.each do |name, command|
      padding = ' '*(31 - name.length)
      output << "\t#{name + padding + command[:description]}\n"
    end
    return output
  end

    
  def method_missing(method, *a, &b) # meta programming for DRYness
    if Flag::TYPES.include?(method.to_s) # option adding
      add_option method, *a
    elsif META.include?(method.to_s) # singular meta data adding
      add_meta method, a[0]
    elsif METAS.include?(method.to_s) # plural meta data adding
      add_metas method, a[0]
    else
      super method, *a, &b
    end
  end

  
  class FlagContainer < Hash
    def initialize
      @flags = []
      super
    end
    
    def output_options
      unless empty?
        output = "\nOptions:\n"
        @flags.each { |f| output << f.format + "\n" }
        return output
      end
    end
    
    def add( flag )
      @flags << flag
      self[flag.long_name] = self[flag.options[:short_name]] = flag
    end
      
      
    def uniq?( value )
      return false if self.has_key? value
      value
    end
  end
  class Flag
    TYPES = %w(string int file bool)

    attr_reader :type
    attr_reader :long_name
    attr_reader :options
    
    def initialize( type, long_name, options = {})
      @type = type
      @long_name = long_name
      @options = options
    end
    
    
    def set( value )
      @value = case @type
        when :string, :int
          value || Regina.next_arg || @options[:default]
        when :bool
          true
      end
      validate_type
      
      return @value
    end
    
    
    def set_default( value )
      @options[:default] = value
      set( value )
    end
      
      
    def validate_type
      case @type
        when :string
          if ! @value
            error "'--#{@long_name}' requires a string value"
          end
        when :int
          if ! @value.validate(:int)
            error "#{@long_name} requires an integer value"
          end
        when :file
          if ! File.exists?(@value)
            error "#{@long_name} requires a file"
          end
        when :bool
          true
      end
    end
    
    
    def format
      padding = ' '*(25 - @long_name.length)
      "\t-#{options[:short_name]}, --#{@long_name + padding + @options[:description]}"
    end
  end
end


# extensions because I can
class String
  def validate(type)
    case type
      when :int
        return true if self =~ /^[0-9]*$/
      else
        nil
    end
    false
  end
end
class NilClass # Oh no I didn't
  def validate(type)
    false
  end
end
module Kernel
  def error( message )
    puts "\e[1m\e[31mError:\e[0m #{message}"
    exit
  end
  
  def warning( message )
    puts "\e[1m\e[33mWarning:\e[0m #{message}"
  end
end
