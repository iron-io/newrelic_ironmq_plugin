require 'iron_mq'
require 'iron_cache'
require 'yaml'
require 'newrelic_platform'

def config; @config ||= YAML.load_file('./ironmq_agent.config.yml'); end

p @config

begin
  @ironmq = IronMQ::Client.new(config['iron_mq'])
  @cache = IronCache::Client.new(config['iron']).cache('newrelic-ironmq-agent')
rescue Exception => err
  abort 'Iron.io credentials are wrong.'
end


@new_relic = NewRelic::Client.new(:license => config['newrelic']['license'],
                                  :guid => 'io.iron.mq',
                                  :version => '2',
                                  )


# Helpers
def duration(from, to)
  dur = from ? (to - from).to_i : 3600

  dur > 3600 ? 3600 : dur
end

def up_to(to = nil)
  if to
    @up_to = Time.at(to.to_i).utc
  else
    @up_to ||= Time.now.utc
  end
end

def processed_at(processed = nil)
  if processed
    @cache.put('previously_processed_at', processed.to_i)

    @processed_at = Time.at(processed.to_i).utc
  elsif @processed_at.nil?
    item = @cache.get 'previously_processed_at'
    min_prev_allowed = (up_to - 3600).to_i

    at = if item && item.value.to_i > min_prev_allowed
           item.value
         else
           min_prev_allowed
         end

    @processed_at = Time.at(at).utc
  else
    @processed_at
  end
end

p "########################################### START"
# Process
collector = @new_relic.new_collector
component = collector.component('Queues')

queues = []
page = 0
per_page = 100
n_results = 0
begin
  qs = @ironmq.queues_list(page: page, per_page: per_page)
  p queues |= qs
  n_results = qs.size
end while n_results == per_page

# For each queue
overall = {size: 0, total: 0, rate: 0.0}
p queues.count
queues.each do |q|
  info = q.info
  size = info["size"]
  total = info["total_messages"]
  name = info["name"]

  # Add Queue Size Component
  puts "\nFound queue: #{name} [#{size} size, #{total} total messages]"
  component.add_metric "#{name}/Total", 'messages', total
  overall[:total] += total
  component.add_metric "#{name}/Size", 'messages', size
  overall[:size] += size

  # Calculate Queue Rate
  key = "#{config['iron']['project_id']}_#{name}_last_total"
  item = @cache.get(key)
  last_total = rate = 0
  if item
    last_total = item.value
    dur = duration(processed_at, up_to)
    rate = ((total - last_total) / dur.to_f).round(2)
  end
  @cache.put(key, total)
  puts "Total was #{last_total}, now #{total}  [Rate #{rate} messages/sec]"

  component.add_metric "#{name}/Rate", 'messages/sec', rate
  overall[:rate] += rate
end
p" ************************************************"
p OpenSSL::SSL::SSLContext::DEFAULT_PARAMS[:ssl_version]
p OpenSSL::SSL::SSLContext::DEFAULT_PARAMS[:ssl_version] = "SSLv23"

component.add_metric 'All Queues/Total', 'messages', overall[:total]
component.add_metric 'All Queues/Size', 'messages', overall[:size]
component.add_metric 'All Queues/Rate', 'messages/sec', overall[:rate]

component.options[:duration] = duration(processed_at, up_to)

begin
  # Submit data to New Relic
  collector.submit
rescue Exception => err
  # restore_stderr
  if err.message.downcase =~ /http 403/
    abort "Seems New Relic's license key is wrong."
  else
    abort("Error happened while sending data to New Relic. " +
          "Error message: '#{err.message}'.")
  end
end

p processed_at(up_to)

p "done"
