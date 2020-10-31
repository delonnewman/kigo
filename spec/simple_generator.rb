class SimpleGenerator
  def self.generate
    @generator ||= new
    @generator.generate
  end
end