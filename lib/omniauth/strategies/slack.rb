require 'omniauth/strategies/oauth2'
require 'uri'
require 'rack/utils'

module OmniAuth
  module Strategies
    class Slack < OmniAuth::Strategies::OAuth2
      option :name, 'slack'

      option :authorize_options, [:scope, :team]

      option :client_options, {
        site: 'https://slack.com',
        token_url: '/api/oauth.access'
      }

      option :auth_token_params, {
        mode: :query,
        param_name: 'token'
      }

      # User ID is not guaranteed to be globally unique across all Slack users.
      # The combination of user ID and team ID, on the other hand, is guaranteed
      # to be globally unique.
      uid { "#{auth['installer_user']['user_id']}-#{auth['team_id']}" }

      info do
        # {"ok"=>true, "token_type"=>"app", "app_id"=>"ACQC5BN6M", "app_user_id"=>"UCQC86XJ5", "team_name"=>"zaprri", "team_id"=>"T3B3T2E82", "authorizing_user"=>{"user_id"=>"U3BQ0E0UX", "app_home"=>"DCS157FU7"}, "installer_user"=>{"user_id"=>"U3BQ0E0UX", "app_home"=>"DCS157FU7"}, "scopes"=>{"app_home"=>["im:history", "conversations:read", "chat:write", "commands", "im:read"], "team"=>["users.profile:read"], "channel"=>["channels:history", "conversations:read", "chat:write", "commands"], "group"=>["groups:history", "conversations:read", "chat:write", "commands"], "mpim"=>["conversations:read", "chat:write", "commands"], "im"=>["im:history", "conversations:read", "chat:write", "commands"]}}
        hash = {
          name: user_identity['name'],
          email: user_identity['email'],    # Requires the identity.email scope
          image: user_identity['image_48'], # Requires the identity.avatar scope
          team_id: auth['team_id'],
          team: auth['team_name'],
          installing_user: auth['installer_user']['user_id'],
          app_user_id: auth['app_user_id'],
        }

        unless skip_info?
          [:first_name, :last_name, :phone].each do |key|
            hash[key] = user_info['user'].to_h['profile'].to_h[key.to_s]
          end
        end

        hash
      end

      extra do
        {
          raw_info: {
            team_identity: team_identity,  # Requires identify:basic scope
            user_identity: user_identity,  # Requires identify:basic scope
            user_info: user_info,         # Requires the users:read scope
            team_info: team_info,         # Requires the team:read scope
            web_hook_info: web_hook_info,
            bot_info: bot_info
          }
        }
      end

      def authorize_params
        super.tap do |params|
          %w[scope team].each do |v|
            if request.params[v]
              params[v.to_sym] = request.params[v]
            end
          end
        end
      end

      def identity
        @identity ||= access_token.get('/api/users.identity').parsed
      end

      def user_identity
        @user_identity ||= identity['user'].to_h
      end

      def team_identity
        @team_identity ||= identity['team'].to_h
      end

      def user_info
        url = URI.parse('/api/users.info')
        url.query = Rack::Utils.build_query(user: user_identity['id'])
        url = url.to_s

        @user_info ||= access_token.get(url).parsed
      end

      def team_info
        @team_info ||= access_token.get('/api/team.info').parsed
      end

      def web_hook_info
        return {} unless access_token.params.key? 'incoming_webhook'
        access_token.params['incoming_webhook']
      end

      def bot_info
        return {} unless access_token.params.key? 'bot'
        access_token.params['bot']
      end

      def auth
        @auth ||= access_token.params.to_h
      end
    end
  end
end
