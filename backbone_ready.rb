# >----------------------------[ Initial Setup ]------------------------------<

initializer 'generators.rb', <<-RUBY
Rails.application.config.generators do |g|
end
RUBY

@recipes = ["devise", "git", "heroku", "rspec", "backbone", "sass"] 

def recipes; @recipes end
def recipe?(name); @recipes.include?(name) end

def say_custom(tag, text); say "\033[1m\033[36m" + tag.to_s.rjust(10) + "\033[0m" + "  #{text}" end
def say_recipe(name); say "\033[1m\033[36m" + "recipe".rjust(10) + "\033[0m" + "  Running #{name} recipe..." end
def say_wizard(text); say_custom(@current_recipe || 'wizard', text) end

def yes_wizard?(question)
  answer = ask_wizard(question + " \033[33m(y/n)\033[0m")
  case answer.downcase
  when "yes", "y"
    true
  when "no", "n"
    false
  else
    yes_wizard?(question)
  end
end

def ask_wizard(question)
  ask "\033[1m\033[30m\033[46m" + (@current_recipe || "prompt").rjust(10) + "\033[0m\033[36m" + "  #{question}\033[0m"
end

def no_wizard?(question); !yes_wizard?(question) end

@current_recipe = nil
@configs = {}

@after_blocks = []
def after_bundler(&block); @after_blocks << [@current_recipe, block]; end
@after_everything_blocks = []
def after_everything(&block); @after_everything_blocks << [@current_recipe, block]; end
@before_configs = {}
def before_config(&block); @before_configs[@current_recipe] = block; end



# >--------------------------------[ Devise ]---------------------------------<

@current_recipe = "devise"
@before_configs["devise"].call if @before_configs["devise"]
say_recipe 'Devise'

config = {}
config['use'] = yes_wizard?("Do you want devise?")
config['user_model'] = yes_wizard?("Do you want a devise User model?") if config['use']

@configs[@current_recipe] = config


if config['use']
  gem 'devise'
end

after_bundler do
  generate 'devise:install' if config['use']
  generate 'devise user'    if config['user_model']
end


# >----------------------------------[ Git ]----------------------------------<

@current_recipe = "git"
@before_configs["git"].call if @before_configs["git"]
say_recipe 'Git'


@configs[@current_recipe] = config

after_everything do
  git :init
end


# >--------------------------------[ Heroku ]---------------------------------<

@current_recipe = "heroku"
@before_configs["heroku"].call if @before_configs["heroku"]
say_recipe 'Heroku'

config = {}
config['create'] = yes_wizard?("Automatically create appname.heroku.com?") if true && true unless config.key?('create')
@configs[@current_recipe] = config

heroku_name = app_name.gsub('_','')

after_everything do
  if config['create']
    say_wizard "Creating Heroku app..."
    system("heroku create")
  end
end


# >----------------------------[ RSpec and friends ]-----------------------------<

@current_recipe = "rspec"
@before_configs["rspec"].call if @before_configs["rspec"]
say_recipe 'RSpec'

config = {}
@configs[@current_recipe] = config

gem_group :development, :test do
  gem 'rspec-rails'
  gem 'capybara'
  gem 'factory_girl_rails'
  gem 'shoulda-matchers'
end

inject_into_file "config/initializers/generators.rb", :after => "Rails.application.config.generators do |g|\n" do
  "    g.test_framework = :rspec\n"
end

after_bundler do
  generate 'rspec:install'
end


# >---------------------------------[ Backbone ]---------------------------------<

@current_recipe = "backbone"
@before_configs["backbone"].call if @before_configs["backbone"]
say_recipe 'Backbone'

config = {}
@configs[@current_recipe] = config

after_bundler do

  inside "app/assets" do
    empty_directory "templates"
    create_file "templates/.gitkeep"
  end

  inside "app/assets/javascripts" do
    run "rm application.js"

    empty_directory "lib"
    empty_directory "models"
    empty_directory "controllers"
    empty_directory "collections"
    empty_directory "routers"
    empty_directory "helpers"
    empty_directory "views"

    create_file "models/.gitkeep"
    create_file "controllers/.gitkeep"
    create_file "collections/.gitkeep"
    create_file "routers/.gitkeep"
    create_file "helpers/.gitkeep"
    create_file "views/.gitkeep"
    create_file "events.js.coffee" do
      "class App.e extends Backbone.Events"
    end

    create_file "application.js.coffee" do
      <<-COFFEE
#= require jquery
#= require jquery_ujs
#= require lib/underscore-min
#= require lib/backbone-min
#= require_tree ../templates
#= require_self
#= require events
#= require_tree ./models
#= require_tree ./collections
#= require_tree ./views
#= require_tree ./routers
#= require_tree ./helpers

window.App =
  m: {}  # models
  c: {}  # collections
  v: {}  # views
  r: {}  # routers
  h: {}  # helpers

  init: ->
    Backbone.history.start({pushState: true})

$(document).ready ()->
  App.init()

      COFFEE
    end
  end

  inside "app/assets/javascripts/lib" do
    get "http://documentcloud.github.com/backbone/backbone-min.js", "backbone-min.js"
    get "http://documentcloud.github.com/underscore/underscore-min.js", "underscore-min.js"
  end

  inside "app/assets/stylesheets" do
    run "rm application.css"
    create_file "application.css.scss" do
      "@import 'bourbon';"
    end
  end
end



# >---------------------------[ Haml and Sass ]-------------------------------<

@current_recipe = "sass"
@before_configs["sass"].call if @before_configs["sass"]
say_recipe 'Sass'

config = {}
@configs[@current_recipe] = config


gem_group :assets do
  gem 'haml-rails'
  gem 'eco'
  gem 'bourbon'
end

gem_group :development do
  gem 'quiet_assets'
  gem 'sextant'
end



@current_recipe = nil

# >-----------------------------[ Run Bundler ]-------------------------------<

say_wizard "Running Bundler install. This will take a while."
run 'bundle install'
say_wizard "Running after Bundler callbacks."
@after_blocks.each{|b| config = @configs[b[0]] || {}; @current_recipe = b[0]; b[1].call}

@current_recipe = nil
say_wizard "Running after everything callbacks."
@after_everything_blocks.each{|b| config = @configs[b[0]] || {}; @current_recipe = b[0]; b[1].call}
