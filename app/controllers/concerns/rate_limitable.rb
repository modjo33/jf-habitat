module RateLimitable
  extend ActiveSupport::Concern

  class_methods do
    def rate_limit(to:, within:, only: nil, except: nil, key: nil, response: nil)
      before_action(only: only, except: except) do
        bucket = key.respond_to?(:call) ? instance_exec(&key) : (key || self.class.name)
        cache_key = "rate_limit:#{bucket}:#{request.remote_ip}"
        # Read-modify-write : garantit que le compteur porte bien un TTL (expires_in),
        # ce que Cache#increment ne fait pas de façon fiable avec le MemoryStore —
        # sinon un visiteur ayant atteint la limite resterait bloqué jusqu'au redémarrage.
        count = (Rails.cache.read(cache_key) || 0) + 1
        Rails.cache.write(cache_key, count, expires_in: within)
        if count > to
          if response.respond_to?(:call)
            instance_exec(&response)
          else
            head :too_many_requests
          end
        end
      end
    end
  end
end
