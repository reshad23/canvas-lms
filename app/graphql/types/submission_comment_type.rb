#
# Copyright (C) 2019 - present Instructure, Inc.
#
# This file is part of Canvas.
#
# Canvas is free software: you can redistribute it and/or modify it under
# the terms of the GNU Affero General Public License as published by the Free
# Software Foundation, version 3 of the License.
#
# Canvas is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE. See the GNU Affero General Public License for more
# details.
#
# You should have received a copy of the GNU Affero General Public License along
# with this program. If not, see <http://www.gnu.org/licenses/>.
#

module Types
  class SubmissionCommentType < ApplicationObjectType
    graphql_name 'SubmissionComment'

    implements Interfaces::TimestampInterface

    field :_id, ID, 'legacy canvas id', null: true, method: :id
    field :comment, String, null: true

    field :author, Types::UserType, null: true
    def author
      # We are preloading submission and assignment here for the permission check.
      # Not ideal as that could be cached in redis, but in most cases the assignment
      # and submission will already be in the cache, as that's the graphql query
      # path to get to a submission comment, and thus costs us nothing to preload here.
      Promise.all([
        load_association(:author),
        load_association(:submission).then do |submission|
          Loaders::AssociationLoader.for(Submission, :assignment).load(submission)
        end
      ]).then {
        object.author if object.grants_right?(current_user, :read_author)
      }
    end

    field :attachments, [Types::FileType], null: true
    def attachments
      attachment_ids = object.parse_attachment_ids
      return [] if attachment_ids.empty?

      load_association(:submission).then do |submission|
        Loaders::AssociationLoader.for(Submission, :assignment).load(submission).then do |assignment|
          scope = assignment.attachments
          Loaders::ForeignKeyLoader.for(scope, :id).load_many(attachment_ids).then do |attachments|
            # ForeignKeyLoaders returns results as an array and load_many also returns the values
            # as an array. Flatten them so we are not returning nested arrays here.
            attachments.flatten.compact
          end
        end
      end
    end

    field :media_object, Types::MediaObjectType, null: true
    def media_object
      Loaders::MediaObjectLoader.load(object.media_comment_id)
    end
  end
end
