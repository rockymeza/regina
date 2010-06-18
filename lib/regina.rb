module Regina
  VERSION = '0.0.1'

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
      @flags = {}
      @argv = []
      
      self.instance_eval &b
      
      @meta[:usage].flatten!
      @meta[:authors].flatten!
      
      parse_flags until ARGV.empty?
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
    
    
    def parse_flags
      argv = ARGV.shift
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
      else
        return @argv << argv
      end
      warning "What do you want me to do with '#{arg}'?"
    end
    
    
    def set_option( arg )
      if arg.is_a? MatchData
        flag, value = arg[1], arg[2]
      else
        flag = arg
      end
      
      @options[ @flags[ flag ].long_name ] = ( case @flags[ flag ].type
        when :string || :int
          value || ARGV.shift
        when :bool
          true
      end )
    end
    
    
    def add_option( type, long_name, description, options = {})
      options[:description] = description
      options[:short_name] ||= shorten_name( long_name )
      
      @flags[ options[:short_name] ] = @flags[long_name] = Flag.new( type, long_name, options )
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
    
    
    def shorten_name(long_name, hash = @flags)
      short_name = SPECIAL_NAMES[ long_name ] ||
                   hash.uniq?( long_name[0] ) ||
                   hash.uniq?( long_name[0].capitalize )
      
      error 'Could not determine short_name for option: #{long_name}.  Please specify one.' if ! short_name
      
      short_name
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
    end
  end
  
  class CommandParser < Parser
  end
  
  def new *a, &b
    return Parser.new(*a, &b) if b
  end
  module_function :new

end

class Hash
  def uniq?( value )
    return false if self.has_key? value
    value
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
