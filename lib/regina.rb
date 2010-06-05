module Regina
  VERSION = 0.0.1

  class Parser
    
    def initialize *a, &b
      cloaker(&b).bind(self).call(*a)
    end

    def foo
      puts "whee"
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
    Parser.new *a, &b if b
  end
  module_function :new

end

Regina.new do
  foo
end
