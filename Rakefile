# -*- ruby -*-

require 'rubygems'
require 'hoe'
$:.unshift 'lib'
require 'sphincter'

Hoe.new('Sphincter', Sphincter::VERSION) do |p|
  p.rubyforge_name = 'seattelrb'
  p.author = 'Eric Hodel'
  p.email = 'drbrain@segment7.net'
  p.summary = p.paragraphs_of('README.txt', 4).first
  p.description = p.paragraphs_of('README.txt', 5).first
  p.url = p.paragraphs_of('README.txt', 2).first
  p.changes = p.paragraphs_of('History.txt', 0..1).join("\n\n")

  p.extra_deps << ['rake', '>= 0.7.3']
  p.extra_deps << ['rails', '>= 1.2.3']
end

# vim: syntax=Ruby
