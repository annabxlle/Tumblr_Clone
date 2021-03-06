# == Schema Information
#
# Table name: users
#
#  id                     :integer          not null, primary key
#  username               :string(255)
#  email                  :string(255)
#  blog_name              :string(255)
#  password_digest        :string(255)
#  session_token          :string(255)
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  provider               :string(255)
#  uid                    :string(255)
#  avatar_file_name       :string(255)
#  avatar_content_type    :string(255)
#  avatar_file_size       :integer
#  avatar_updated_at      :datetime
#  password_reset_token   :string(255)
#  password_reset_sent_at :datetime
#  phonenumber            :string(255)
#

class User < ActiveRecord::Base
  attr_accessible :username, :email, :blog_name, :password, :provider, :uid, :avatar, :phonenumber
  attr_reader :password
    
  before_validation :ensure_session_token
  validates :username, :email, :blog_name, presence: true
  validates :username, :email, :blog_name, length: 4..40
  validates :email, format: { with: /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\Z/i }
  validates :username, uniqueness: true
  validates :email, uniqueness: true
  validates :password, length: 4..15, allow_nil: true
  
  has_many :posts, dependent: :destroy
  has_many :sent_activs, class_name: "Activ", foreign_key: "sent_user_id", dependent: :destroy
  has_many :got_activs,  class_name: "Activ", foreign_key: "got_user_id",  dependent: :destroy
  has_many :followers, class_name: "Following", foreign_key: "followed_id", dependent: :destroy
  has_many :followers_users, through: :followers, source: :follower
  has_many :following, class_name: "Following", foreign_key: "follower_id", dependent: :destroy
  has_many :following_users, through: :following, source: :followed
  has_many :likes, dependent: :destroy
  has_many :liked_posts, through: :likes, source: :post
  
  # PAPERCLIP
  has_attached_file :avatar, styles: {small: "100x100>"}, default_url: "/assets/avatar_64_default1.png"
  validates_attachment_content_type :avatar, :content_type => %w[image/jpeg image/jpg image/png]
  validates_attachment :avatar, allow_nil: true, :size => { :in => 0..1000.kilobytes }
  
  def self.most_liked(except)
    User.find_by_sql(
    "SELECT users.*, COUNT(likes.id) AS count
    FROM users
    JOIN posts ON users.id = posts.user_id
    JOIN likes ON posts.id = likes.post_id
    WHERE users.id NOT IN (#{except.join(",")})
    GROUP BY users.id
    ORDER BY count DESC
    LIMIT 3")
  end
  
  def self.find_or_create_by_auth(auth, current_user)
    user = User.find_by_uid(auth['uid'])
    if user
      if current_user && user != current_user
        return false
      else
        return user
      end
    end
      
    user = User.find_by_email(auth['info']['email'])
    
    if user
      user.update_attributes({provider: auth['provider'], uid: auth['uid']})
      return user
    end
    
    if current_user
      current_user.update_attributes({provider: auth['provider'], uid: auth['uid']})
      return current_user
    end

    user = User.create!(
      username: auth['info']['nickname'],
      email: auth['info']['email'],
      blog_name: auth['info']['name'],
      password: auth['uid'],
      provider: auth['provider'],
      uid: auth['uid'])
    return user
  end
  
  def password=(password)
    @password = password
    self.password_digest = BCrypt::Password.create(password)
  end
  
  def self.find_by_credentials(email, password)
    user = User.find_by_email(email)
    return nil unless user
    BCrypt::Password.new(user.password_digest).is_password?(password) ? user : nil
  end
  
  def reset_session_token!
    self.session_token = SecureRandom::urlsafe_base64(16)
    self.save!
    return self.session_token
  end
  
  def ensure_session_token
    self.session_token ||= SecureRandom::urlsafe_base64(16)
  end
  
  def send_password_reset
    self.password_reset_token = SecureRandom.urlsafe_base64(16)
    self.password_reset_sent_at = Time.zone.now
    self.save!
    UserMailer.password_reset(self).deliver
  end
  
  def src_small
    avatar? ? avatar.url : "No"
  end
end
