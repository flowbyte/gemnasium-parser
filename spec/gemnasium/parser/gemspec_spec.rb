require "spec_helper"

describe Gemnasium::Parser::Gemspec do
  def content(string)
    @content ||= begin
      indent = string.scan(/^[ \t]*(?=\S)/)
      n = indent ? indent.size : 0
      string.gsub(/^[ \t]{#{n}}/, "")
    end
  end

  def gemspec
    @gemspec ||= Gemnasium::Parser::Gemspec.new(@content)
  end

  def dependencies
    @dependencies ||= gemspec.dependencies
  end

  def dependency
    expect(dependencies.size).to eq(1)
    dependencies.first
  end

  def reset
    @content = @gemspec = @dependencies = nil
  end

  it "parses double quotes" do
    content(<<-EOF)
      Gem::Specification.new do |gem|
        gem.add_dependency "rake", ">= 0.8.7"
      end
    EOF
    expect(dependency.name).to eq("rake")
    expect(dependency.requirement.as_list).to eq([">= 0.8.7"])
  end

  it "parses single quotes" do
    content(<<-EOF)
      Gem::Specification.new do |gem|
        gem.add_dependency 'rake', '>= 0.8.7'
      end
    EOF
    expect(dependency.name).to eq("rake")
    expect(dependency.requirement.as_list).to eq([">= 0.8.7"])
  end

  it "ignores mixed quotes" do
    content(<<-EOF)
      Gem::Specification.new do |gem|
        gem.add_dependency "rake', ">= 0.8.7"
      end
    EOF
    expect(dependencies.size).to eq(0)
  end

  it "parses gems with a period in the name" do
    content(<<-EOF)
      Gem::Specification.new do |gem|
        gem.add_dependency "pygment.rb", ">= 0.8.7"
      end
    EOF
    expect(dependency.name).to eq("pygment.rb")
    expect(dependency.requirement.as_list).to eq([">= 0.8.7"])
  end

  it "parses non-requirement gems" do
    content(<<-EOF)
      Gem::Specification.new do |gem|
        gem.add_dependency "rake"
      end
    EOF
    expect(dependency.name).to eq("rake")
    expect(dependency.requirement.as_list).to eq([">= 0"])
  end

  it "parses multi-requirement gems" do
    content(<<-EOF)
      Gem::Specification.new do |gem|
        gem.add_dependency "rake", ">= 0.8.7", "<= 0.9.2"
      end
    EOF
    expect(dependency.name).to eq("rake")
    expect(dependency.requirement.as_list).to eq([">= 0.8.7", "<= 0.9.2"])
  end

  it "parses single-element array requirement gems" do
    content(<<-EOF)
      Gem::Specification.new do |gem|
        gem.add_dependency "rake", [">= 0.8.7"]
      end
    EOF
    expect(dependency.name).to eq("rake")
    expect(dependency.requirement.as_list).to eq([">= 0.8.7"])
  end

  it "parses multi-element array requirement gems" do
    content(<<-EOF)
      Gem::Specification.new do |gem|
        gem.add_dependency "rake", [">= 0.8.7", "<= 0.9.2"]
      end
    EOF
    expect(dependency.name).to eq("rake")
    expect(dependency.requirement.as_list).to eq([">= 0.8.7", "<= 0.9.2"])
  end

  it "parses runtime gems" do
    content(<<-EOF)
      Gem::Specification.new do |gem|
        gem.add_dependency "rake"
        gem.add_runtime_dependency "rails"
      end
    EOF
    expect(dependencies[0].type).to eq(:runtime)
    expect(dependencies[1].type).to eq(:runtime)
  end

  it "parses dependency gems" do
    content(<<-EOF)
      Gem::Specification.new do |gem|
        gem.add_development_dependency "rake"
      end
    EOF
    expect(dependency.type).to eq(:development)
  end

  it "records dependency line numbers" do
    content(<<-EOF)
      Gem::Specification.new do |gem|
        gem.add_dependency "rake"

        gem.add_dependency "rails"
      end
    EOF
    expect(dependencies[0].instance_variable_get(:@line)).to eq(2)
    expect(dependencies[1].instance_variable_get(:@line)).to eq(4)
  end

  it "parses parentheses" do
    content(<<-EOF)
      Gem::Specification.new do |gem|
        gem.add_dependency("rake", ">= 0.8.7")
      end
    EOF
    expect(dependency.name).to eq("rake")
    expect(dependency.requirement.as_list).to eq([">= 0.8.7"])
  end

  it "parses gems followed by inline comments" do
    content(<<-EOF)
      Gem::Specification.new do |gem|
        gem.add_dependency "rake", ">= 0.8.7" # Comment
      end
    EOF
    expect(dependency.name).to eq("rake")
    expect(dependency.requirement.as_list).to eq([">= 0.8.7"])
  end
end
