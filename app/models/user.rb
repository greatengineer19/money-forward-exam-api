class User < ApplicationRecord
	has_secure_password
  
  # Validations
  validates :email, 
            presence: true, 
            uniqueness: { case_sensitive: false }, 
            format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, 
            length: { minimum: 6 }, 
            if: -> { new_record? || !password.nil? }
  validates :first_name, :last_name, presence: true
  
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
  
  def full_name
    "#{first_name} #{last_name}"
  end
  
  def to_s
    full_name
  end
end
