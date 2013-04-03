
## IronMQ New Relic Agent

**Who:** Any user of IronMQ - a highly available cloud message queue service by [Iron.io](http://iron.io).

**What:** This agent (extended from this [generic SaaS agent](https://github.com/newrelic-platform/ironworker_saas_agent)) runs on the [IronWorker](http://iron.io/worker) platform (another service by [Iron.io](http://iron.io)) and collects data from IronMQ to send to your own New Relic account.

**Why:** Visualizing your IronMQ data in New Relic is awesome!

**How:** The following instructions describe how to configure and schedule the "IronWorker" to run every minute, collect data, and send to New Relic. It's simple, fast, and **free**!

1. Create free account at [Iron.io](http://iron.io) if you don't already have one
1. Create free account at [New Relic](http://newrelic.com) if you don't already have one
1. Fill in config/config.yml
1. Upload it: `iron_worker upload my_service_agent`
1. Test it: `iron_worker queue my_service_agent` - check it at hud.iron.io
1. Schedule it: `iron_worker schedule my_service_agent --run-every 60`

That's it! You will now see data in New Relic for all the queues in the project specified in the config.yml.
