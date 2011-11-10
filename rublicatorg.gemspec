require File.expand_path("../lib/rublicatorg", __FILE__)

Gem::Specification.new do |s|
  s.name              = 'rublicatorg'
  s.rubyforge_project = "rublicatorg"

  s.version           = RublicatorG::VERSION
  s.platform          = Gem::Platform::RUBY

  s.summary           = "ReplicatorG in Ruby!"
  s.description       = "Communicate with a MakerBot 3D Printer"
  s.authors           = ["Tony Buser"]
  s.email             = 'tbuser@gmail.com'
  s.homepage          = 'http://github.com/tbuser/RublicatorG'

  s.require_paths     = ["lib"]
  s.files             = Dir["{lib}/**/*.rb", "bin/*", "examples/*", "test/*", "LICENSE", "README.rdoc"]
  s.executables       = ['rublicatorg']
  
  s.add_dependency("serialport")
  s.add_dependency("parseconfig")
end