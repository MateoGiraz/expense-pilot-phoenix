SimpleCov.start 'rails' do
  add_filter '/config/'
  add_filter '/db/'
  add_filter '/vendor/'
  add_filter '/spec/'
  add_filter '/test/'
  add_filter '/bin/'
  add_filter '/script/'
  add_filter '/tmp/'
  add_filter '/log/'
  add_filter '/public/'
  add_filter '/storage/'
  add_filter 'Rakefile'
  add_filter 'config.ru'
  
  # Group coverage by directories
  add_group "Models", "app/models"
  add_group "Controllers", "app/controllers"
  add_group "Views", "app/views"
  add_group "Helpers", "app/helpers"
  add_group "Jobs", "app/jobs"
  add_group "Mailers", "app/mailers"
  add_group "Libraries", "lib"
  
  # No minimum coverage requirement - only informational
  # minimum_coverage 100
  # maximum_coverage_drop 0
  
  # Refuse to merge results that are older than this many seconds
  merge_timeout 3600
  
  # Track files that were never even loaded during tests
  track_files "app/**/*.rb"
  
  # Coverage format options
  formatter SimpleCov::Formatter::HTMLFormatter
end 