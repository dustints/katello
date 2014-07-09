#
# Copyright 2014 Red Hat, Inc.
#
# This software is licensed to you under the GNU General Public
# License as published by the Free Software Foundation; either version
# 2 of the License (GPLv2) or (at your option) any later version.
# There is NO WARRANTY for this software, express or implied,
# including the implied warranties of MERCHANTABILITY,
# NON-INFRINGEMENT, or FITNESS FOR A PARTICULAR PURPOSE. You should
# have received a copy of GPLv2 along with this software; if not, see
# http://www.gnu.org/licenses/old-licenses/gpl-2.0.txt.

module Actions
  module Katello
    module Subscription
      class SyncQpidEntitlementPoolQueue < Dynflow::Action
        include Dynflow::Action::Polling

        def humanized_name
          "Qpid Queue Subscription Polling Task"
        end

        def done?
          false
        end

        def poll_external_task
          @@notifier.retreive_and_notify
          true
        end

        def invoke_external_task
          @@notifier = ::Katello::QpidQueueObserver.new(::Katello.config.qpid.url, {:transport => 'ssl'}, ::Katello.config.qpid.subscriptions_queue_address)
          @@notifier.start
          @@notifier.register(ReindexPoolSubscriptionHandler.new)
          true
        end

        def poll_intervals
          [2, 4, 8, 16]
        end
      end

      class ReindexPoolSubscriptionHandler
        LOGGER = Rails.logger
        def notify(message)
          LOGGER.debug("message received from subscriptions queue ")
          LOGGER.debug("message subject: #{message.subject}")

          ::User.current = ::User.anonymous_admin

          debugger
          case message.subject
          when /entitlement\.(deleted|created)$/
            content = JSON.parse(message.content)
            pool_id = content['referenceId']
            pool = ::Katello::Pool.find_pool(pool_id)
            debugger
            LOGGER.info "re-indexing #{pool_id}."
            ::Katello::Pool.index_pools([pool])
          else
            LOGGER.fatal "message subject unexpected."
            raise "message subject unexpected"
          end
        end
      end

    end
  end
end
