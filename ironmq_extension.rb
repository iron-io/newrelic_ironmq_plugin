require 'rest'
require 'iron_mq'
require 'iron_cache'
require 'yaml'

# Requires manual installation of the New Relic plaform gem (platform is in closed beta)
# https://github.com/newrelic-platform/iron_sdk
require 'newrelic_platform'

config = YAML.load_file('config/config.yml')

ironmq = IronMQ::Client.new(
  token: config['iron']['token'],
  project_id: config['iron']['project_id'],
)

ironcache = IronCache::Client.new(
  token: config['iron']['token'],
  project_id: config['iron']['project_id'],
)

cache = ironcache.cache("ironmq_agent_cache")

queues = ironmq.queues.all

new_relic = NewRelic::Client.new(:license => config['newrelic']['license'],
                                  :guid => config['newrelic']['guid'],
                                  :version => config['newrelic']['version'])

collector = new_relic.new_collector

# For each queue
queues.each do |q|
  size = q.size
  name = q.name

  # Add Queue Size Component
  puts "\nFound queue: #{name} [#{size} messages]"
  component = collector.component(name)
  component.add_metric 'Queued Messages', 'messages', size

  # Calculate Queue Rate
  key = "#{config['iron']['project_id']}_#{name}_lastsize"
  item = cache.get(key)
  if item.nil?
    lastsize = rate = 0
  else
    lastsize = item.value
    rate=(((size-lastsize)/60).to_f).round(2)
  end
  cache.put(key, size)
  puts " Size was #{lastsize}, now #{size}  [Rate #{rate} messages/sec]"

  # Add Queue Rate Component
  component = collector.component(name)
  component.add_metric 'Message Rate', 'messages/sec', rate


  # Submit data to New Relic
  response = collector.submit
  puts "Response --> #{response.code}"
end
