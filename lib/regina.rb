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
      
      @flags = {}
      @short_names = []
      
      cloaker(&b).bind(self).call(*a)
      
      @meta[:usage].flatten!
      @meta[:authors].flatten!
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
      @flags[key]
    end
    
    
    def add_option( type, long_name, description, options = {})
      options[:long_name] = long_name
      options[:description] = description
      options[:short_name] ||= shorten_name( long_name )
      
      @short_names << options[:short_name]
      @flags[long_name] = Flag.new( type, options )
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
                   @short_names.uniq?( long_name[0] ) ||
                   @short_names.uniq?( long_name[0].capitalize )
      
      error 'Could not determine short_name for option: #{long_name}.  Please specify one.' if ! short_name
      
      short_name
    end
    
    class Flag
      attr_reader :type
      attr_reader :options
      
      def initialize( type, options = {})
        @type = type
        @options = options
        
        make_name
      end
      
      def make_name
        if options[:short_name].nil?
          
        end
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

class Array
  def uniq?( value )
    return false if self.include? value
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
  by 'Roc and Wil'
  copyright '2010'
  usage 'pirate [options]'
  usage 'pirate [subcommand] [options]'
  
  bool 'aargh', 'Do you want pirates?', :function => :if_pirates
  int 'number', 'How many pirates?', :short => 'x', :function => :output_pirates
end

p a
