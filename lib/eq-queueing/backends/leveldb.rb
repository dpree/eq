require 'leveldb'

module EQ::Queueing::Backends

  # @note This is a unoreded storage, so there is no guaranteed work order
  # @note assume there is nothing else than jobs
  class LevelDB
    class JobsCollection < Struct.new(:db, :name)
      include EQ::Logging

      PAYLOAD            = 'payload'.freeze
      CREATED_AT         = 'created_at'.freeze
      STARTED_WORKING_AT = 'started_working_at'.freeze
      NOT_WORKING = ''.freeze

      def push payload
        job_id = find_free_job_id
        db["#{PAYLOAD}:#{job_id}"] = payload
        db["#{CREATED_AT}:#{job_id}"] = serialize_time(Time.now)
        db["#{STARTED_WORKING_AT}:#{job_id}"] = NOT_WORKING
        job_id
      end

      def first_waiting
        if raw = db.each{|k,v| break [k,v] if k.include?(STARTED_WORKING_AT) && v == NOT_WORKING}
          job_id_from_key(raw.first)
        end
      end

      def working_iterator
        db.each do |k,v|
          if k.include?(STARTED_WORKING_AT) && v != NOT_WORKING
            yield job_id_from_key(k), deserialize_time(v)
          end
        end
      end

      def delete job_id
        did_exist = !db["#{PAYLOAD}:#{job_id}"].nil?
        db.batch do |batch|
          batch.delete "#{PAYLOAD}:#{job_id}"
          batch.delete "#{CREATED_AT}:#{job_id}"
          batch.delete "#{STARTED_WORKING_AT}:#{job_id}"
        end
        does_not_exist = db["#{PAYLOAD}:#{job_id}"].nil?
        did_exist && does_not_exist
      end

      def start_working job_id
        db["#{STARTED_WORKING_AT}:#{job_id}"] = serialize_time(Time.now)
      end

      def stop_working job_id
        db["#{STARTED_WORKING_AT}:#{job_id}"] = NOT_WORKING
      end

      def find_payload job_id
        db["#{PAYLOAD}:#{job_id}"]
      end

      def find_created_at job_id
        if serialized_time = db["#{CREATED_AT}:#{job_id}"]
          deserialize_time(serialized_time)
        end
      end

      def find_started_working_at job_id
        if serialized_time = db["#{STARTED_WORKING_AT}:#{job_id}"]
          deserialize_time(serialized_time)
        end
      end

      def job_id_from_key key
        prefix, job_id = *key.split(':')
        job_id
      end

      # try as hard as you can to find a free slot
      def find_free_job_id
        loop do
          job_id = generate_id
          break job_id unless db.contains? "#{PAYLOAD}:#{job_id}"
          sleep 0.05
          log_error "#{job_id} is not free"
        end
      end

      # Time in milliseconds and 4 digit random
      # @note Maybe this is a stupid idea, but for now it kinda works :)
      def generate_id
        '%d%04d' % [(Time.now.to_f * 1000.0).to_i, Kernel.rand(1000)]
      end

      def serialize_time time
        Marshal.dump(time)
      end

      def deserialize_time serialized_time
        Marshal.load(serialized_time)
      end

      def count
        result = 0
        db.each do |k,v|
          result += 1 if k.include?(PAYLOAD)
        end
        result
      end

      def count_waiting
        result = 0
        db.each do |k,v|
          if k.include?(STARTED_WORKING_AT) && v == NOT_WORKING
            result += 1
          end
        end
        result
      end

      def count_working
        result = 0
        db.each do |k,v|
          if k.include?(STARTED_WORKING_AT) && v != NOT_WORKING
            result += 1
          end
        end
        result
      end
    end

    attr_reader :db
    attr_reader :jobs

    def initialize config
      @db = ::LevelDB::DB.new config
      @jobs = JobsCollection.new(db)
    end

    def push payload
      jobs.push payload
    end

    def reserve
      if job_id = jobs.first_waiting
        jobs.start_working job_id
        [job_id, jobs.find_payload(job_id)]
      end
    end

    def pop job_id
      jobs.delete job_id
    end

    def requeue_timed_out_jobs
      requeued = 0
      jobs.working_iterator do |job_id, started_working_at|
        # older than x
        if started_working_at <= (Time.now - EQ.config.job_timeout)
          jobs.stop_working job_id
          requeued += 1
        end
      end
      requeued
    end

    def count name=nil
      case name
      when :waiting
        jobs.count_waiting
      when :working
        jobs.count_working
      else
        jobs.count
      end
    end
  end
end