module Regina
  VERSION = '0.0.1'

  class Parser
    
    SPECIAL_NAMES = { 
      :dry_run => :n }

    def initialize( *a, &b )
      @meta = {}
      @meta[:title] = nil
      @meta[:authors] = []
      @meta[:copyright] = nil
      @meta[:usage] = []
      
      @options = {}
      @flags = {}
      @argv = []
      
      cloaker(&b).bind(self).call(*a)
      
      @meta[:usage].flatten!
      @meta[:authors].flatten!
      
      parse until ARGV.empty?
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
    
    
    def parse
      if arg = ARGV.shift.match( /^-(?:-)?([a-z0-9]+)$/i )
        if @flags.has_key? arg[1]
          set_option arg[1]
        else
          arg[1].each_char do |c|
            set_option c if @flags.has_key?( c )
          end
        end
      else
        @argv << arg[1]
      end
    end
    
    
    def set_option( flag )
      @options[ @flags[ flag ].long_name ] = ( case @flags[ flag ].type
        when :bool
          true
        when :string
          ARGV.shift
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
    
    
    def int( long_name, description, options = {} )
      add_option :int, long_name, description, options
    end
    alias :integer :int
    
    
    def string( long_name, description, options = {} )
      add_option :string, long_name, description, options
    end
    
    
    def shorten_name(long_name)
      short_name = SPECIAL_NAMES[ long_name ] ||
                   @flags.uniq?( long_name[0] ) ||
                   @flags.uniq?( long_name[0].capitalize )
      
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


    # thanks to _why
    def cloaker &b
      (class << self; self; end).class_eval do
        define_method :cloaker_, &b
        meth = instance_method :cloaker_
        remove_method :cloaker_
        meth
      end
    end

  end

  def new *a, &b
    return Parser.new *a, &b if b
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
end

a = Regina.new do
  title 'Pirate Program'
  by 'Rocky Meza'
  by 'William Scales'
  copyright '2010'
  usage 'pirate [options]'
  usage 'pirate [subcommand] [options]'
  
  bool 'aargh', 'Do you want pirates?'
  string 'asdf', 'Blahdy blah?'
  int 'number', 'How many pirates?', :short_name => 'x'
end

p a
