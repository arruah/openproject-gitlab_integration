module OpenProject::GitlabIntegration
  class HookHandler
    # List of the gitlab events we can handle.
    KNOWN_EVENTS = ['Push Hook' => 'push', 'Note Hook' => 'note', 'Merge Request Hook' => 'merge_request'].freeze

    # A gitlab webhook happened.
    # We need to check validity of the data and send a Notification
    # which we process in our NotificationHandler.
    def process(hook, request, params, user)
      event_type = request.env['HTTP_X_GITLAB_EVENT']
      event_delivery = request.env['HTTP_X_GITLAB_DELIVERY']

      Rails.logger.debug "Received gitlab webhook: #{event_type}"

      KNOWN_EVENTS['push']

      return 404 unless KNOWN_EVENTS.include?(event_type) && event_delivery
      return 403 unless user.present?

      payload = params[:payload]
                .permit!
                .to_h
                .merge('open_project_user_id' => user.id,
                       'gitlab_event' => event_type,
                       'gitlab_delivery' => event_delivery)


      OpenProject::Notifications.send(event_object_kind(event_type), payload)

      return 200
    end

    # gitlab_object_kind: 'push' | 'note' | 'merge_request'
    private def event_object_kind(gitlab_object_kind)
      "gitlab.#{KNOWN_EVENTS[gitlab_object_kind]}"
    end
  end
end