class SearchVector < ActiveRecord::Base

  WEIGHT_VALUES = [
    0.03, # D
    0.1,  # C
    0.3,  # B
    1.0   # A
  ]

  DISCUSSION_FIELD_WEIGHTS = {
    'discussions.title'        => :A,
    'motion_names'             => :B,
    'discussions.description'  => :C,
    'motion_descriptions'      => :C,
    'comment_bodies'           => :D
  }

  belongs_to :discussion
  self.table_name = 'discussion_search_vectors'

  class << self
    def index!(discussion_ids)
      discussion_ids = Array(discussion_ids).map(&:to_i)
      where(discussion_id: discussion_ids).delete_all
      discussion_ids.each do |discussion_id|
        connection.execute index_thread_sql(discussion_id)
        yield if block_given?
      end
    end
    handle_asynchronously :index!

  end

  def self.index_everything!
    index_without_delay! Discussion.pluck(:id)
  end

  def self.index_thread_sql(discussion_id)
    "INSERT INTO discussion_search_vectors (discussion_id, search_vector)
     SELECT      id, #{discussion_field_weights}
     FROM        discussions
     LEFT JOIN (
       SELECT string_agg(name, ',')                     AS motion_names,
              LEFT(string_agg(description, ','), 10000) AS motion_descriptions
       FROM   motions
       WHERE  discussion_id = #{discussion_id}) motions ON #{discussion_id} = id
     LEFT JOIN (
       SELECT LEFT(string_agg(body, ','), 200000)       AS comment_bodies
       FROM   comments
       WHERE  discussion_id = #{discussion_id}) comments ON #{discussion_id} = id
     WHERE    id = #{discussion_id}"
  end

  def self.discussion_field_weights
    DISCUSSION_FIELD_WEIGHTS.map { |field, weight| "setweight(to_tsvector(coalesce(#{field}, '')), '#{weight}')" }.join ' || '
  end

  scope :search_for, ->(query, user, opts = {}) do
    Queries::VisibleDiscussions.apply_privacy_sql(
      user: user,
      group_ids: user.cached_group_ids,
      relation: joins(discussion: :group).search_without_privacy!(query, user, opts)
    )
  end

  scope :search_without_privacy!, ->(query, user, opts = {}) do
    query = sanitize(query)
    self.select(:discussion_id, :search_vector, 'groups.full_name as result_group_name')
        .select("ts_rank_cd('{#{WEIGHT_VALUES.join(',')}}', search_vector, plainto_tsquery(#{query})) as rank")
        .where("search_vector @@ plainto_tsquery(#{query})")
        .order('rank DESC')
        .offset(opts.fetch(:from, 0))
        .limit(opts.fetch(:per, 10))
  end

end
