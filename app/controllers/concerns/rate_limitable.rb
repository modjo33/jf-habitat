module RateLimitable
  extend ActiveSupport::Concern

  class_methods do
    def rate_limit(to:, within:, only: nil, except: nil, key: nil, response: nil)
      before_action(only: only, except: except) do
        bucket = key.respond_to?(:call) ? instance_exec(&key) : (key || self.class.name)
        cache_key = "rate_limit:#{bucket}:#{request.remote_ip}"
        count = Rails.cache.increment(cache_key, 1, expires_in: within)
        if count.to_i > to
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
