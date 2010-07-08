module Regina
  VERSION = '0.0.1'
  
  
  def next_flag
    if ARGV[0] && ARGV[0][0] == '-'
      return ARGV.shift
    end
  end
  module_function :next_flag
  
  
  def next_arg
    if ARGV[0] && ARGV[0][0] != '-'
      return ARGV.shift
    end
  end
  module_function :next_arg
  
  
  class Parser
    
    SPECIAL_NAMES = { 
      :dry_run => :n }
      
    attr_reader :options
    attr_reader :argv
    attr_reader :flags

    def initialize( *a, &b )
      @meta = {}
      @meta[:title] = nil
      @meta[:authors] = []
      @meta[:copyright] = nil
      @meta[:usage] = []
      
      @options = {}
      @commands = {}
      @flags = FlagContainer.new
      @argv = []
      
      self.instance_eval &b
      
      @meta[:usage].flatten!
      @meta[:authors].flatten!
      
      check_commands if ! @commands.empty?
      unless @options.has_key?( :command )
        parse_flags until ARGV.empty?
      end
    end
    
    
    def title( title )
      @meta[:title] = title
    end
    
    
    def author( author )
      @meta[:authors] << author
    end
    alias :by :author
    
    
    def copyright( copyright )
      @meta[:copyright] = copyright
    end
    
    
    def usage( usage )
      @meta[:usage] << usage
    end
    
    
    def []( key )
      @options[key.to_s]
    end
    
    
    def check_commands
      if @commands.has_key?(ARGV[0])
        command = Regina.next_arg
        @options[ :command ] = command
        command_options = Regina.new @commands[ command ][ :block ]
        @options[ :command_options ] = command_options
      end
    end
    
    
    def parse_flags
      if argv = Regina.next_flag
        if argv.match( /^-h|--help$/ )
          help
        elsif arg = argv.match( /^--([a-z0-9]+)(?:=(.*?))?$/mi ) # two dashes
          return set_option arg if @flags.has_key?( arg[1] )
        elsif arg = argv.match( /^-([a-z0-9])(?:=(.*?))?$/mi ) # single dash
          return set_option arg if @flags.has_key?( arg[1] )
        elsif arg = argv.match( /^-([a-z0-9]+$)/mi )
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
    
    
    def bool( long_name, description, options = {} )
      add_option :bool, long_name, description, options
    end
    alias :boolean :bool
    
    
    def int( long_name, description, options = {} )
      add_option :int, long_name, description, options
    end
    alias :integer :int
    
    
    def string( long_name, description, options = {} )
      add_option :string, long_name, description, options
    end
    alias :text :string
    
    
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
EOS
      puts message
      exit
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
          when :bool
            true
        end
      end
      
      
      def format
        "\t-#{options[:short_name]}, --#{@long_name}\t\t\t#{options[:description]}"
      end
    end
  end
  
  class CommandParser < Parser
  end
  
  def new *a, &b
    return Parser.new(*a, &b) if b
  end
  module_function :new

end

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
