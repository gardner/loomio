class ThreadSearchQuery

  WEIGHT_VALUES = [
    0.03, # D
    0.1,  # C
    0.3,  # B
    1.0   # A
  ]

  def initialize(query, user: nil, offset: 0, limit: 5, since: nil, till: nil)
    @query, @user, @offset, @limit, @since, @until = ActiveRecord::Base.sanitize(query), user, offset, limit, since, till
  end

  def search_results
    @search_results ||=
      Discussion.select(:id, :group_id, :title, :description, :last_activity_at, :rank, "#{@query} as query")
                .select(blurb_for('discussions.description'))
                .from(visible_search_vectors)
                .joins("INNER JOIN discussions on subquery.discussion_id = discussions.id")
                .where('rank > 0')
                .order('rank DESC, last_activity_at DESC')
  end

  private

  def visible_search_vectors
    @visible_search_vectors ||=
      Queries::VisibleDiscussions.apply_privacy_sql(user: @user, group_ids: @user.cached_group_ids, relation: search_vectors)
  end

  def search_vectors
    @search_vectors ||=
      SearchVector.select(:discussion_id, :search_vector)
                  .select(rank_for(column: :search_vector))
                  .from('discussion_search_vectors')
                  .joins(discussion: :group)
                  .where("search_vector @@ plainto_tsquery(#{@query})")
                  .order('rank DESC')
                  .offset(@offset)
                  .limit(@limit)
  end

  def rank_for(vector: nil, column: 'search_vector')
    "ts_rank_cd('{#{WEIGHT_VALUES.join(',')}}', #{weights_for(vector) || column}, plainto_tsquery(#{@query})) as rank"
  end

  def weights_for(vector)
    return unless vector
    vector.map { |field, weight| "setweight(to_tsvector(coalesce(#{field}, '')), '#{weight}')" }.join ' || '
  end

  def blurb_for(field)
    "ts_headline(#{field}, plainto_tsquery(#{@query}), 'ShortWord=0') as blurb"
  end

  def relevant_records_for(model)
    return [] unless Rails.application.secrets.advanced_search_enabled
    SearchVector.execute_search_query self.class.send(:"relevant_#{model}_sql", top_results.map { |d| d['id'] }), query: @query
  end

  def index_thread_sql
    "INSERT INTO discussion_search_vectors (discussion_id, search_vector)
     SELECT      id, #{weights_for(discussion_field_weights)}
     FROM        discussions
     LEFT JOIN (
       SELECT string_agg(name, ',')                     AS motion_names,
              LEFT(string_agg(description, ','), 10000) AS motion_descriptions
       FROM   motions
       WHERE  discussion_id = :id) motions ON :id = id
     LEFT JOIN (
       SELECT LEFT(string_agg(body, ','), 200000)       AS comment_bodies
       FROM   comments
       WHERE  discussion_id = :id) comments ON :id = id
     WHERE    id = :id"
  end

  # def self.relevant_motions_sql(top_ids)
  #   "SELECT   DISTINCT ON (discussion_id)
  #             id,
  #             discussion_id,
  #             name,
  #             #{rank_sql(motion_field_weights)} as rank,
  #             #{field_as_blurb_sql('description')} as blurb
  #    FROM     motions
  #    WHERE    motions.discussion_id IN (#{top_ids.join(',')})
  #    AND      #{field_weights_sql(motion_field_weights)} @@ plainto_tsquery(:query)
  #    ORDER BY discussion_id, rank DESC"
  # end
  #
  # def self.relevant_comments_sql(top_ids)
  #   "SELECT   DISTINCT ON (discussion_id)
  #             id,
  #             discussion_id,
  #             user_id,
  #             #{rank_sql(comment_field_weights)} as rank,
  #             #{field_as_blurb_sql('body')} as blurb
  #    FROM     comments
  #    WHERE    comments.discussion_id IN (#{top_ids.join(',')})
  #    AND      #{field_weights_sql(comment_field_weights)} @@ plainto_tsquery(:query)
  #    ORDER BY discussion_id, rank DESC"
  # end

  private

  def discussion_field_weights
    {
      'discussions.title'        => :A,
      'motion_names'             => :B,
      'discussions.description'  => :C,
      'motion_descriptions'      => :C,
      'comment_bodies'           => :D
   }
  end
  #
  # def motion_field_weights
  #   {'name'        => :B,
  #    'description' => :C}
  # end
  #
  # def comment_field_weights
  #   {'body' => :D} # So happy :D
  # end

end
