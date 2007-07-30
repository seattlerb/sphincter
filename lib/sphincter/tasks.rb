require 'rake'
require 'sphincter/configure'

namespace :sphincter do

  desc 'Creates sphinx.conf if it doesn\'t exist'
  task :configure => :environment do
    sphinx_conf = Sphincter::Configure.sphinx_conf
    Rake::Task['sphincter:reconfigure'].invoke unless File.exist? sphinx_conf
  end

  desc 'Creates sphinx.conf'
  task :reconfigure => :environment do
    Sphincter::Configure.configure
  end

  desc 'Runs the sphinx indexer if the indexes don\'t exist'
  task :index => :configure do
    indexes_defined = Sphincter::Configure.index_count
    sphinx_dir = Sphincter::Configure.get_conf['sphincter']['path']

    indexes_found = Dir[File.join(sphinx_dir, '*.spd')].length

    Rake::Task['sphincter::reindex'].invoke if indexes_found > indexes_defined
  end

  desc 'Runs the sphinx indexer'
  task :reindex => :configure do
    sphinx_conf = Sphincter::Configure.sphinx_conf
    cmd = %W[indexer --all --config #{sphinx_conf}]
    cmd << "--quiet" unless Rake.application.options.trace
    cmd << "--rotate" if Sphincter::Configure.searchd_running?
    system(*cmd)
  end

  desc 'Stops searchd, reconfigures and reindexes'
  task :reset => :configure do
    Rake::Task['sphincter:stop_searchd'].invoke
    FileUtils.rm_rf Sphincter::Configure.sphinx_dir,
                    :verbose => Rake.application.options.trace
    Rake::Task['sphincter:reconfigure'].execute # force reindex
    Rake::Task['sphincter:reindex'].invoke
  end

  desc 'Restarts the searchd sphinx daemon'
  task :restart_searchd => %w[sphincter:stop_searchd sphincter:start_searchd]

  desc 'Starts the searchd sphinx daemon'
  task :start_searchd => :index do
    unless Sphincter::Configure.searchd_running? then
      cmd = "searchd --config #{Sphincter::Configure.sphinx_conf}"
      cmd << " > /dev/null" unless Rake.application.options.trace
      system cmd
    end
  end

  desc 'Stops the searchd daemon'
  task :stop_searchd => :configure do
    pid = Sphincter::Configure.searchd_running?
    system 'kill', pid if pid
  end

end

