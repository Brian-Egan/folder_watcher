require 'rubygems'
require 'bundler/setup'
require 'yaml'
Bundler.require

# Make sure there's only one process running
if File.file?('daemons.rb.pid')
  system 'kill -15 $(cat daemons.rb.pid) &>/dev/null 2>&1'
end

# Load the settings from YAML into a hash.
SETTINGS = YAML.load_file('settings.yml')

# Match an FS Event path to its root folder.
def match_root_folder(path)
  SETTINGS.each_key do |key|
    return SETTINGS[key] if path.index(SETTINGS[key]['path'])
  end
  return nil
end

def add_variables_to_command(command, variables = [])
  variables.each_with_index do |var, indx|
    command.gsub!("{VARIABLE#{indx + 1}}", var)
  end
  command 
end

# Define watcher options and paths to watch.
options = {:latency => '5', :no_defer => false}
paths = SETTINGS.map {|key,value| value["path"]}

# Define the watcher.
fsevent = FSEvent.new
fsevent.watch(paths, options) do |dirs|
  applied_settings = []
  fsevent.stop
  dirs.each do |dir|  
    settings = match_root_folder(dir)
    if settings && !(applied_settings.include? settings)
      # applied_settings = applied_settings + [settings]
      applied_settings << settings
      command = add_variables_to_command(settings['command'], settings["variables"])
      system command
    end
  end
  fsevent.run
end

# Daemonize the process.
Daemons.daemonize

# Run the FSEvent watcher.
fsevent.run
