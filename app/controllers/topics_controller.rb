class TopicsController < ApplicationController

  before_filter :authenticate_user!, :except => ['show','index','tag','make_private']
  before_filter :instantiate_tracker

  # GET /topics
  # GET /topics.xml
  def index
    @forum = Forum.find(params[:forum_id])
    @topics = @forum.topics.ispublic.chronologic.page params[:page]

    #@feed_link = "<link rel='alternate' type='application/rss+xml' title='RSS' href='#{forum_topics_url}.rss' />"

    @page_title = @forum.name.titleize
    @title_tag = "#{Settings.site_name}: #{@page_title}"
    add_breadcrumb t(:community, default: "Community"), forums_path
    add_breadcrumb @forum.name.titleize

    respond_to do |format|
      format.html # index.rhtml
      format.xml  { render :xml => @topics.to_xml }
      format.rss
    end
  end

  def tickets

    @topics = current_user.topics.isprivate.chronologic.page params[:page]
    @page_title = t(:tickets, default: 'Tickets')
    add_breadcrumb @page_title

    @title_tag = "#{Settings.site_name}: #{@page_title}"

    #@feed_link = "<link rel='alternate' type='application/rss+xml' title='RSS' href='#{forum_topics_url}.rss' />"

    respond_to do |format|
      format.html # index.rhtml
      format.xml  { render :xml => @topics.to_xml }
      format.rss
    end
  end


  def ticket

    @topic = Topic.find(params[:id])
    @posts = @topic.posts.active.all

    @page_title = "##{@topic.id} #{@topic.name.titleize}"
    add_breadcrumb t(:tickets, default: 'Tickets')
    add_breadcrumb @page_title

    @title_tag = "#{Settings.site_name}: #{@page_title}"

    respond_to do |format|
      format.html # index.rhtml
      format.xml  { render :xml => @topics.to_xml }
      format.rss
    end


  end


  # GET /topics/1
  # GET /topics/1.xml
  def show

  end

  # GET /topics/new
  def new


    @page_title = t(:start_discussion, default: "Start a New Discussion")
    add_breadcrumb @page_title
    @title_tag = "#{Settings.site_name}: #{@page_title}"

    @topic = Topic.new

  end

  # GET /topics/1;edit
  def edit
    @topic = Topic.find(params[:id])
  end

  # POST /topics
  # POST /topics.xml
  def create
    params[:id].nil? ? @forum = Forum.find(params[:topic][:forum_id]) : @forum = Forum.find(params[:id])
    logger.info(@forum.name)

    @topic = @forum.topics.new(
      name: params[:topic][:name],
      user_id: current_user.id,
      private: params[:topic][:private] )
    @topic.save

#    @topic.tag_list = params[:tags]
#    @topic.save

    @post = @topic.posts.new(:body => params[:post][:body], :user_id => current_user.id, :kind => 'first')

    respond_to do |format|

      if @post.save
        # track event in GA
        @tracker.event(category: 'Request', action: 'Post', label: 'New Topic')
        @tracker.event(category: 'Agent: Unassigned', action: 'New', label: @topic.to_param)

        format.html {
          if @topic.private?
            redirect_to ticket_path(@topic)
          else
            redirect_to topic_posts_path(@topic)
          end
          }
      else
        format.html { render action: 'new' }
      end
    end
  end

  # PUT /topics/1
  # PUT /topics/1.xml
  def update
    @topic = Topic.find(params[:id])
    @topic.tag_list = params[:tags]
    respond_to do |format|
      if @topic.update_attributes(params[:topic])
        #flash[:notice] = 'Topic was successfully updated.'
        format.html { redirect_to topic_posts_path(@topic) }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @topic.errors.to_xml }
      end
    end
  end

  # DELETE /topics/1
  # DELETE /topics/1.xml
  def destroy
    @topic = Topic.find(params[:id])
    @topic.posts.each { |post| post.destroy }
    @topic.destroy

    respond_to do |format|
      format.html { redirect_to forum_topics_path(@topic.forum) }
      format.xml  { head :ok }
    end
  end

  def up_vote
    @topic = Topic.find(params[:id])
    @topic.votes.create(:user_id => current_user.id)
    logger.info(current_user.id)
    @topic.reload
    if request.xhr?
      render :update do |page|
        page['topic-stats'].replace_html :partial => 'posts/topic_stats'
      end
    else
      redirect_to topic_posts_path(@topic)
    end
  end

  def down_vote
    @topic = Topic.find(params[:id])
    @topic.votes.create(:user_id => current_user, :points => -1)

    @topic.reload
    if request.xhr?
      render :update do |page|
        page['topic-stats'].replace_html :partial => 'posts/topic_stats'
      end
    else
      redirect_to topic_posts_path(@topic)
    end
  end

  def tag
    @topics = Topic.ispublic.tag_counts_on(:tags)
  end
end