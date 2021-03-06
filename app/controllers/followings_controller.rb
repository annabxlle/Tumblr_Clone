class FollowingsController < ApplicationController
  before_filter :require_current_user!
  before_filter :get_menu_stats
  
  def followers
    @followings = current_user.following_users
    @followers  = current_user.followers_users
  end
  
  def following
    @following = current_user.following_users.includes(:posts)
  end
  
  def create
    follower_id = params[:follower_id]
    following = Following.new({follower_id: current_user.id,
                               followed_id: follower_id})
    user = User.find(follower_id).username
    
    if following.save
      Activ.create({sent_user_id: current_user.id, got_title: "#{current_user.username} started following you", got_user_id: follower_id})
      
      if request.xhr?
        render text: "Started following \"#{user}\""
      else
        flash[:main] = "You started following \"#{user}\""
        (params[:back].nil?) ? (redirect_to root_url) : (redirect_to params[:back])
      end
      
    else
      flash[:main] = "Error in trying to follow \"#{user}\""
      (params[:back].nil?) ? (redirect_to root_url) : (redirect_to params[:back])
    end
    
  end
  
  def destroy
    if params[:follower_id]
      following = Following.where("follower_id=? AND followed_id=?", params[:follower_id], current_user.id).first
    else
      following = Following.where("follower_id=? AND followed_id=?", current_user.id, params[:followed_id]).first
    end
    
    if following.destroy
      
      if request.xhr?
        render text: "Removed from the following list"
      else
        flash[:main] = "Removed from the following list"
        (params[:back].nil?) ? (redirect_to root_url) : (redirect_to params[:back])        
      end
      
    else
      flash[:main] = "Error in trying to unfollow"
      (params[:back].nil?) ? (redirect_to root_url) : (redirect_to params[:back])
    end
    
  end
end
