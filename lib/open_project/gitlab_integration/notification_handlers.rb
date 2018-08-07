module OpenProject::GitlabIntegration

  ##
  # Handles gitlab-related notifications.
  module NotificationHandlers

    def self.push(payload)
      comment_on_referenced_work_packages payload['pull_request']['body'], payload
    end

    ##
    # Handles an issue_comment webhook notification.
    # The payload looks similar to this:
    # { open_project_user_id: <the id of the OpenProject user in whose name the webhook is processed>,
    #   github_event: 'issue_comment',
    #   github_delivery: <randomly generated ID idenfitying a single github notification>,
    # Have a look at the github documentation about the next keys:
    # http://developer.github.com/v3/activity/events/types/#pullrequestevent
    #   action: 'created',
    #   issue: <details of the pull request/github issue>
    #   comment: <details of the created comment>
    # We observed the following keys to appear. However they are not documented by github
    #   sender: <the github user who opened a pull request> (might not appear on closed,
    #           synchronized, or reopened - we habven't checked)
    #   repository: <the repository in action>
    # }
    def self.note(payload)
      # if the comment is not associated with a PR, ignore it
      return unless payload['issue']['pull_request']['html_url']
      comment_on_referenced_work_packages payload['comment']['body'], payload
    rescue => e
      Rails.logger.error "Failed to handle pull_request event: #{e} #{e.message}"
      raise e
    end

    ##
    # Parses the text for links to WorkPackages and adds a comment
    # to those WorkPackages depending on the payload.
    def self.comment_on_referenced_work_packages(text, payload)
      user = User.find_by_id(payload['open_project_user_id'])
      wp_ids = extract_work_package_ids(text)
      wps = find_visible_work_packages(wp_ids, user)

      # FIXME check user is allowed to update work packages
      # TODO mergeable

      attributes = { journal_notes: notes_for_payload(payload) }
      wps.each do |wp|
        ::WorkPackages::UpdateService
          .new(user: user, work_package: wp)
          .call(attributes: attributes)
      end
    end

    ##
    # Parses the given source string and returns a list of work_package ids
    # which it finds.
    # WorkPackages are identified by their URL.
    # Params:
    #  source: string
    # Returns:
    #   Array<int>
    def self.extract_work_package_ids(source)
      # matches the following things (given that `Setting.host_name` equals 'www.openproject.org')
      #  - http://www.openproject.org/wp/1234
      #  - https://www.openproject.org/wp/1234
      #  - http://www.openproject.org/work_packages/1234
      #  - https://www.openproject.org/subdirectory/work_packages/1234
       # Or with the following prefix: OP#
      # e.g.,: This is a reference to OP#1234
      host_name = Regexp.escape(Setting.host_name)
      wp_regex = /OP#(\d+)|http(?:s?):\/\/#{host_name}\/(?:\S+?\/)*(?:work_packages|wp)\/([0-9]+)/

      source.scan(wp_regex)
        .map {|first, second| (first || second).to_i }
        .select { |el| el > 0 }
        .uniq
    end

    ##
    # Given a list of work package ids this methods returns all work packages that match those ids
    # and are visible by the given user.
    # Params:
    #  - Array<int>: An list of WorkPackage ids
    #  - User: The user who may (or may not) see those WorkPackages
    # Returns:
    #  - Array<WorkPackage>
    def self.find_visible_work_packages(ids, user)
      ids.collect do |id|
        WorkPackage.includes(:project).find_by_id(id)
      end.select do |wp|
        wp.present? && user.allowed_to?(:add_work_package_notes, wp.project)
      end
    end

    ##
    # Find a matching translation for the action specified in the payload.
    def self.notes_for_payload(payload)
      case payload['gitlab_object_kind']
        when 'push'
          notes_for_push_payload(payload)
        when 'issue_comment'
          notes_for_note_payload(payload)
        when 'merge_request'
          notes_for_merge_request_payload(payload)
        else
          raise "Gitlab event not supported: #{payload['gitlab_event']}"
      end
    end

    def self.notes_for_push_payload(payload)
      push_commits = []
      payload['commits'].each do |commit|
        push_commits.push(I18n.t("gitlab_integration.push_comment",
              :commit_hash => commit['id'],
              :commit_url => commit['url'],
              :message => commit['message'],
              :author_commit => commit['author']['name']
        ))
      end

      I18n.t("gitlab_integration.push_comment",
             :gitlab_user => payload['user_name'],
             :branch_name => payload['ref'],
             :branch_url => payload['ref'], #@todo deve verificar a url do repositorio
             :repository => payload['repository']['name'],
             :repository_url => payload['repository']['homepage'],
             :push_commits => push_commits.join("\n")
      )
    end
  end
end