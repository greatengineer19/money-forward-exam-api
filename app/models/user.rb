class User < ApplicationRecord
  has_secure_password

  validate :duplicate_user_id, on: :create
  validate :password_and_userid_presence
  validate :update_val, on: :update

  validates :user_id, length: {
    minimum: 6,
    maximum: 20,
    message: "Input length is incorrect"
  }

  validates :user_id, format: {
    with: /\A[a-zA-Z0-9]{6,20}\z/,
    message: "Incorrect character pattern"
  }

  validates :password, format: {
    with: /\A[\x21-\x7E]+\z/,
    message: "Incorrect character pattern"
  }, if: :password_required?

  validates :password, length: {
    minimum: 8,
    maximum: 20,
    message: "Input length is incorrect"
  }, if: :password_required?

  # Associations
  has_many :posts, dependent: :destroy
  has_many :comments, dependent: :destroy

  # Scopes
  scope :admins, -> { where(role: 'admin') }
  scope :regular_users, -> { where(role: 'user') }

  # Methods
  def admin?
    role == 'admin'
  end

  def password_required?
    password.present?
  end

  def full_name
    "#{first_name} #{last_name}"
  end

  def to_s
    full_name
  end

  def update_val
    if comment.blank? && nickname.blank?
      errors.add(:base, "Required nickname or comment")
    end
  end

  def duplicate_user_id
    return unless User.find_by(user_id: user_id).present?

    errors.add(:base, "Already same user_id is used")
  end

  def password_and_userid_presence
    if user_id.blank? && password.blank?
      errors.add(:base, "Required user_id and password")
    elsif user_id.blank?
      errors.add(:base, "Required user_id")
    elsif password.blank?
      errors.add(:base, "Required password")
    end
  end
end
