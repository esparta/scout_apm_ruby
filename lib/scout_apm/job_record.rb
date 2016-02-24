# Records details about all runs of a given job.
#
# Contains:
#   Queue Name
#   Job Name
#   Job Runtime - histogram
#   Metrics collected during the run (Database, HTTP, View, etc)
module ScoutApm
  class JobRecord
    attr_reader :queue_name
    attr_reader :job_name
    attr_reader :runtime
    attr_reader :metric_set

    def initialize(queue_name, job_name, total_time, metrics)
      @queue_name = queue_name
      @job_name = job_name
      @runtime = NumericHistogram.new(50)
      @runtime.add(total_time)
      @metric_set = MetricSet.new
      @metric_set.absorb_all(metrics)
    end

    # Modifies self and returns self, after merging in `other`.
    def combine!(other)
      same_job = queue_name == other.queue_name && job_name == other.job_name
      raise "Mismatched Merge of Background Job" unless same_job

      @metric_set = metric_set.combine!(other.metric_set)
      @runtime.combine!(other.runtime)

      self
    end

    # TODO: Should this belong here, or in the renderer?  Feels a bit like a
    # view-layer concern
    def timings
      {
        "0" => runtime.quantile(0),
        "25" => runtime.quantile(25),
        "50" => runtime.quantile(50),
        "75" => runtime.quantile(75),
        "95" => runtime.quantile(95),
        "100" => runtime.quantile(100),
        "avg" => runtime.mean,
      }
    end

    def run_count
      runtime.total
    end

    def metrics
      metric_set.metrics
    end


    ######################
    # Hash Key interface
    ######################

    def ==(o)
      self.eql?(o)
    end

    def hash
      h = queue_name.downcase.hash
      h ^= job_name.downcase.hash
      h
    end

    def eql?(o)
     self.class == o.class &&
       queue_name.downcase == o.queue_name.downcase &&
       job_name.downcase == o.job_name.downcase
    end
  end
end
