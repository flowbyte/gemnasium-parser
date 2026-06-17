require "spec_helper"

describe Gemnasium::Parser::Gemfile do
  def content(string)
    @content ||= begin
      indent = string.scan(/^[ \t]*(?=\S)/)
      n = indent ? indent.size : 0
      string.gsub(/^[ \t]{#{n}}/, "")
    end
  end

  def gemfile
    @gemfile ||= Gemnasium::Parser::Gemfile.new(@content)
  end

  def dependencies
    @dependencies ||= gemfile.dependencies
  end

  def dependency
    expect(dependencies.size).to eq(1)
    dependencies.first
  end

  def reset
    @content = @gemfile = @dependencies = nil
  end

  it "parses double quotes" do
    content(%(gem "rake", ">= 0.8.7"))
    expect(dependency.name).to eq("rake")
    expect(dependency.requirement.as_list).to eq([">= 0.8.7"])
  end

  it "parses single quotes" do
    content(%(gem 'rake', '>= 0.8.7'))
    expect(dependency.name).to eq("rake")
    expect(dependency.requirement.as_list).to eq([">= 0.8.7"])
  end

  it "ignores mixed quotes" do
    content(%(gem "rake', ">= 0.8.7"))
    expect(dependencies.size).to eq(0)
  end

  it "parses gems with a period in the name" do
    content(%(gem "pygment.rb", ">= 0.8.7"))
    expect(dependency.name).to eq("pygment.rb")
    expect(dependency.requirement.as_list).to eq([">= 0.8.7"])
  end

  it "parses non-requirement gems" do
    content(%(gem "rake"))
    expect(dependency.name).to eq("rake")
    expect(dependency.requirement.as_list).to eq([">= 0"])
  end

  it "parses multi-requirement gems" do
    content(%(gem "rake", ">= 0.8.7", "<= 0.9.2"))
    expect(dependency.name).to eq("rake")
    expect(dependency.requirement.as_list).to eq([">= 0.8.7", "<= 0.9.2"])
  end

  it "parses gems with options" do
    content(%(gem "rake", ">= 0.8.7", :require => false))
    expect(dependency.name).to eq("rake")
    expect(dependency.requirement.as_list).to eq([">= 0.8.7"])
  end

  it "listens for gemspecs" do
    content(%(gemspec))
    expect(gemfile).to be_gemspec
    expect(gemfile.gemspec).to eq("*.gemspec")
    reset
    content(%(gem "rake"))
    expect(gemfile).not_to be_gemspec
    expect(gemfile.gemspec).to be_nil
  end

  it "parses gemspecs with a name option" do
    content(%(gemspec :name => "gemnasium-parser"))
    expect(gemfile.gemspec).to eq("gemnasium-parser.gemspec")
  end

  it "parses gemspecs with a path option" do
    content(%(gemspec :path => "lib/gemnasium"))
    expect(gemfile.gemspec).to eq("lib/gemnasium/*.gemspec")
  end

  it "parses gemspecs with name and path options" do
    content(%(gemspec :name => "parser", :path => "lib/gemnasium"))
    expect(gemfile.gemspec).to eq("lib/gemnasium/parser.gemspec")
  end

  it "parses gemspecs with parentheses" do
    content(%(gemspec(:name => "gemnasium-parser")))
    expect(gemfile).to be_gemspec
  end

  it "parses gems of a type" do
    content(%(gem "rake"))
    expect(dependency.type).to eq(:runtime)
    reset
    content(%(gem "rake", :type => :development))
    expect(dependency.type).to eq(:development)
  end

  it "parses gems of a group" do
    content(%(gem "rake"))
    expect(dependency.groups).to eq([:default])
    reset
    content(%(gem "rake", :group => :development))
    expect(dependency.groups).to eq([:development])
  end

  it "parses gems of multiple groups" do
    content(%(gem "rake", :group => [:development, :test]))
    expect(dependency.groups).to eq([:development, :test])
  end

  it "recognizes :groups" do
    content(%(gem "rake", :groups => [:development, :test]))
    expect(dependency.groups).to eq([:development, :test])
  end

  it "parses gems in a group" do
    content(<<-EOF)
      gem "rake"
      group :production do
        gem "pg"
      end
      group :development do
        gem "sqlite3"
      end
    EOF
    expect(dependencies[0].groups).to eq([:default])
    expect(dependencies[1].groups).to eq([:production])
    expect(dependencies[2].groups).to eq([:development])
  end

  it "parses gems in a group with parentheses" do
    content(<<-EOF)
      group(:production) do
        gem "pg"
      end
    EOF
    expect(dependency.groups).to eq([:production])
  end

  it "parses gems in multiple groups" do
    content(<<-EOF)
      group :development, :test do
        gem "sqlite3"
      end
    EOF
    expect(dependency.groups).to eq([:development, :test])
  end

  it "parses multiple gems in a group" do
    content(<<-EOF)
      group :development do
        gem "rake"
        gem "sqlite3"
      end
    EOF
    expect(dependencies[0].groups).to eq([:development])
    expect(dependencies[1].groups).to eq([:development])
  end

  it "parses multiple gems in multiple groups" do
    content(<<-EOF)
      group :development, :test do
        gem "rake"
        gem "sqlite3"
      end
    EOF
    expect(dependencies[0].groups).to eq([:development, :test])
    expect(dependencies[1].groups).to eq([:development, :test])
  end

  it "parses inline source" do
    @content = <<~END
      gem "rake"
      gem 'private-pkg', source: 'https://gems.example.com/'
    END

    expect(dependencies[0].source).to be_nil
    expect(dependencies[1].source).to eq('https://gems.example.com/')
  end

  it "parses block source" do
    @content = <<~END
      gem 'rake'

      source 'https://gems.example.com/' do
        gem 'private-pkg'
      end

      gem 'sqlite3'

      source 'https://rubygems.pkg.github.com/example/' do
        gem 'another-pkg'
      end
    END

    expect(dependencies[0].source).to be_nil
    expect(dependencies[1].source).to eq('https://gems.example.com/')
    expect(dependencies[2].source).to be_nil
    expect(dependencies[3].source).to eq('https://rubygems.pkg.github.com/example/')
  end

  it "parses block source and inline source" do
    @content = <<~END
      source 'https://gems.example.com/' do
        gem 'private-pkg'
        gem 'another-pkg', source: 'https://rubygems.pkg.github.com/example/'
      end
    END

    expect(dependencies[0].source).to eq('https://gems.example.com/')
    expect(dependencies[1].source).to eq('https://rubygems.pkg.github.com/example/')
  end

  it "parses block source with parentheses" do
    @content = <<~END
      source("https://gems.example.com/") do
        gem 'private-pkg'
      end
    END

    expect(dependencies[0].source).to eq('https://gems.example.com/')
  end

  it "parses block source with username password" do
    @content = <<~END
      source "https://user:pwd@gems.example.com/" do
        gem 'private-pkg'
      end
    END

    expect(dependencies[0].source).to eq('https://user:pwd@gems.example.com/')
  end

  it "parses sources with single top-level source" do
    @content = <<~END
      source 'https://rubygems.org'
      gem 'rake'
    END

    expect(gemfile.sources).to eq(['https://rubygems.org'])
  end

  it "parses sources with multiple top-level sources" do
    @content = <<~END
      source 'https://rubygems.org'
      source    "https://gems.example.com/"

      gem 'source'
    END

    expect(gemfile.sources).to eq(['https://rubygems.org', 'https://gems.example.com/'])
    expect(gemfile.sources_with_options).to eq([['https://rubygems.org', {}], ['https://gems.example.com/', {}]])
  end

  it "parses sources should ignore inline sources" do
    @content = <<~END
      source 'https://rubygems.org'

      gem 'rake'
      gem 'private-pkg1', source: 'https://gems.example.com/'
      gem 'private-pkg2', source => 'https://gems.example.com/'
    END

    expect(gemfile.sources).to eq(['https://rubygems.org'])
    expect(gemfile.sources_with_options).to eq([['https://rubygems.org', {}]])
  end

  it "parses sources with no source" do
    @content = <<~END
      gem 'rake'
    END

    expect(gemfile.sources).to eq([])
  end

  it "parses sources with multiple" do
    @content = <<~END
      source 'https://rubygems.org'

      source 'https://user:pwd@gems.example.com/' do
        gem 'private-pkg'
      end

      gem 'sqlite3'

      source("https://rubygems.pkg.github.com/example/") do
        gem 'another-pkg'
      end
    END

    expect(gemfile.sources).to eq(['https://rubygems.org', 'https://user:pwd@gems.example.com/', 'https://rubygems.pkg.github.com/example/'])
  end

  it "parses sources with duplicates" do
    @content = <<~END
      source 'https://rubygems.org'

      source 'https://gems.example.com/' do
        gem 'private-pkg'
      end

      source "https://rubygems.org" do
        gem 'another-pkg'
      end
    END

    expect(gemfile.sources).to eq(['https://rubygems.org', 'https://gems.example.com/'])
    expect(gemfile.sources_with_options).to eq([['https://rubygems.org', {}], ['https://gems.example.com/', {}]])
  end

  it "parses source with options" do
    @content = <<~END
      source 'https://rubygems.org', :cooldown => 7
      source 'https://fresh.rubygems.org', cooldown: 0

      source 'https://gems.coop', :cooldown   =>  "4"
      source("https://gems.example.com/",     cooldown:    3) do
        gem 'private-pkg'
      end
    END

    expect(gemfile.sources_with_options).to eq([
      ["https://rubygems.org", {"cooldown" => 7}],
      ["https://fresh.rubygems.org", {"cooldown" => 0}],
      ["https://gems.coop", {"cooldown" => "4"}],
      ["https://gems.example.com/", {"cooldown" => 3}]
    ])
  end

  it "parses weird options" do
    @content = <<~END
      gem 'afm', '~> 0.1.0', :env => ENV['RAILS_ENV']
    END

    expect(dependency.name).to eq("afm")
  end

  it "ignores h4x" do
    path = File.expand_path("../h4x.txt", __FILE__)
    content(%(gem "h4x", :require => "\#{`touch #{path}`}"))
    expect(dependencies.size).to eq(1)
    begin
      expect(File).not_to exist(path)
    ensure
      FileUtils.rm_f(path)
    end
  end

  it "ignores gems with a git option" do
    content(%(gem "rails", :git => "https://github.com/rails/rails.git"))
    expect(dependencies.size).to eq(0)
  end

  it "ignores gems with a github option" do
    content(%(gem "rails", :github => "rails/rails"))
    expect(dependencies.size).to eq(0)
  end

  it "ignores gems with a path option" do
    content(%(gem "rails", :path => "vendor/rails"))
    expect(dependencies.size).to eq(0)
  end

  it "ignores gems in a git block" do
    content(<<-EOF)
      git "https://github.com/rails/rails.git" do
        gem "rails"
      end
    EOF
    expect(dependencies.size).to eq(0)
  end

  it "ignores gems in a git block with parentheses" do
    content(<<-EOF)
      git("https://github.com/rails/rails.git") do
        gem "rails"
      end
    EOF
    expect(dependencies.size).to eq(0)
  end

  it "ignores gems in a path block" do
    content(<<-EOF)
      path "vendor/rails" do
        gem "rails"
      end
    EOF
    expect(dependencies.size).to eq(0)
  end

  it "ignores gems in a path block with parentheses" do
    content(<<-EOF)
      path("vendor/rails") do
        gem "rails"
      end
    EOF
    expect(dependencies.size).to eq(0)
  end

  it "records dependency line numbers" do
    content(<<-EOF)
      gem "rake"

      gem "rails"
    EOF
    expect(dependencies[0].instance_variable_get(:@line)).to eq(1)
    expect(dependencies[1].instance_variable_get(:@line)).to eq(3)
  end

  it "maps groups to types" do
    content(<<-EOF)
      gem "rake"
      gem "pg", :group => :production
      gem "mysql2", :group => :staging
      gem "sqlite3", :group => :development
    EOF
    expect(dependencies[0].type).to eq(:runtime)
    expect(dependencies[1].type).to eq(:runtime)
    expect(dependencies[2].type).to eq(:development)
    expect(dependencies[3].type).to eq(:development)
    reset
    Gemnasium::Parser.runtime_groups << :staging
    content(<<-EOF)
      gem "rake"
      gem "pg", :group => :production
      gem "mysql2", :group => :staging
      gem "sqlite3", :group => :development
    EOF
    expect(dependencies[0].type).to eq(:runtime)
    expect(dependencies[1].type).to eq(:runtime)
    expect(dependencies[2].type).to eq(:runtime)
    expect(dependencies[3].type).to eq(:development)
  end

  it "parses parentheses" do
    content(%(gem("rake", ">= 0.8.7")))
    expect(dependency.name).to eq("rake")
    expect(dependency.requirement.as_list).to eq([">= 0.8.7"])
  end

  it "parses gems followed by inline comments" do
    content(%(gem "rake", ">= 0.8.7" # Comment))
    expect(dependency.name).to eq("rake")
    expect(dependency.requirement.as_list).to eq([">= 0.8.7"])
  end

  it "parses oddly quoted gems" do
    content(%(gem %q<rake>))
    expect(dependency.name).to eq("rake")
  end
end
