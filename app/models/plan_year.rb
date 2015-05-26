class PlanYear
  include Mongoid::Document
  include Mongoid::Timestamps
  include AASM

  embedded_in :employer_profile

  # Plan Year time period
  field :start_on, type: Date
  field :end_on, type: Date

  field :open_enrollment_start_on, type: Date
  field :open_enrollment_end_on, type: Date
  field :published, type: Boolean

  # Number of full-time employees
  field :fte_count, type: Integer, default: 0

  # Number of part-time employess
  field :pte_count, type: Integer, default: 0

  # Number of Medicare second payers
  field :msp_count, type: Integer, default: 0

  field :aasm_state, type: String

  embeds_many :benefit_groups, cascade_callbacks: true
  accepts_nested_attributes_for :benefit_groups, reject_if: :all_blank, allow_destroy: true

  validates_presence_of :start_on, :end_on, :open_enrollment_start_on, :open_enrollment_end_on

  validate :open_enrollment_date_checks

  def parent
    raise "undefined parent employer_profile" unless employer_profile?
    self.employer_profile
  end

  # embedded association: has_many :employee_families
  def employee_families
    return @employee_families if defined? @employee_families
    @employee_families = parent.employee_families.where(:plan_year_id => self.id)
  end

  def effective_date
    start_on.beginning_of_day
  end

  def employee_participation_percent
  end

  def editable?
    !benefit_groups.any?(&:assigned?)
  end

  def open_enrollment_contains?(date)
    (open_enrollment_start_on <= date) && (date <= open_enrollment_end_on)
  end

  def coverage_period_contains?(date)
    return (start_on <= date) if (end_on.blank?)
    (start_on <= date) && (date <= end_on)
  end

  def register_employer
    employer_profile.publish_plan_year 
  end

  def minimum_employer_contribution
    benefit_groups.min_by(&:premium_pct_as_int).premium_pct_as_int unless benefit_groups.size == 0
  end

  def is_application_valid?
    application_warnings.blank? ? true : false
  end

  # Check plan year application for regulatory compliance
  def application_warnings
    warnings = {}

    if benefit_groups.size == 0
      warnings.merge!({benefit_groups: "at least one benefit group must be defined for plan year"})
    end

    unless employer_profile.organization.primary_office_location.address.state.to_s.downcase == HbxProfile::StateAbbreviation.to_s.downcase
      warnings.merge!({primary_office_location: "primary office must be located in #{HbxProfile::StateName}"})
    end

    # Maximum company size at time of initial registration on the HBX
    if fte_count > HbxProfile::ShopSmallMarketFteCountMaximum
      warnings.merge!({fte_count: "number of full time equivalents (FTEs) exceeds maximum allowed (#{HbxProfile::ShopSmallMarketFteCountMaximum})"})
    end

    # Exclude Jan 1 effective date from certain checks
    unless effective_date.yday == 1
      # Employer contribution toward employee premium must meet minimum
      if benefit_groups.size > 0 && (minimum_employer_contribution < HbxProfile::ShopEmployerContributionPercentMinimum)
        warnings.merge!({minimum_employer_contribution: "employer contribution percent toward employee premium (#{minimum_employer_contribution}) is less than minimum allowed (#{HbxProfile::ShopEmployerContributionPercentMinimum})"})
      end
    end

    warnings
  end

  class << self
    def find(id)
      organizations = Organization.where("employer_profile.plan_years._id" => BSON::ObjectId.from_string(id))
      organizations.size > 0 ? organizations.first.employer_profile.plan_years.unscoped.detect { |py| py._id.to_s == id.to_s} : nil
    end
  end

  aasm do
    state :draft, initial: true

    # Plan application as submitted has warnings
    state :publish_pending

    state :published,   :after_enter => :register_employer

    # Published plans are retired following their end on date
    state :retired

    # Non-published plans are expired following their end on date
    state :expired

    event :publish do
      transitions from: :draft, to: :published, :guard => :is_application_valid?
      transitions from: :draft, to: :publish_pending
    end

    # Returns plan to draft state so that it can be edited 
    event :withdraw_pending do
      transitions from: :publish_pending, to: :draft      
    end

    # Submit the plan with application warnings to HBX
    event :force_publish do
      transitions from: :publish_pending, to: :published
    end

    event :deactivate do
      transitions from: :draft, to: :expired
      transitions from: :published, to: :retired
    end

    event :revert do
      transitions from: :published, to: :draft
    end

  end


private

  def open_enrollment_date_checks
    return if start_on.blank? || end_on.blank? || open_enrollment_start_on.blank? || open_enrollment_end_on.blank?
    if start_on.day != 1
      errors.add(:start_on, "must be first day of the month")
    end

    if end_on != Date.civil(end_on.year, end_on.month, -1)
      errors.add(:end_on, "must be last day of the month")
    end

    # TODO: Create HBX object with configuration settings including shop_plan_year_maximum_in_days
    shop_plan_year_maximum_in_days = 365
    if (end_on - start_on) > shop_plan_year_maximum_in_days
      errors.add(:end_on, "must be less than #{shop_plan_year_maximum_in_days} days from start date")
    end

    if open_enrollment_end_on > start_on
      errors.add(:start_on, "can't occur before open enrollment end date")
    end

    if open_enrollment_end_on < open_enrollment_start_on
      errors.add(:open_enrollment_end_on, "can't occur before open enrollment start date")
    end

    if (open_enrollment_end_on - open_enrollment_start_on) < HbxProfile::ShopOpenEnrollmentPeriodMinimum
     errors.add(:open_enrollment_end_on, "open enrollment period is less than minumum: #{HbxProfile::ShopOpenEnrollmentPeriodMinimum} days")
    end

    if (open_enrollment_end_on - open_enrollment_start_on) > HbxProfile::ShopOpenEnrollmentPeriodMaximum.months
     errors.add(:open_enrollment_end_on, "open enrollment period is greater than maximum: #{HbxProfile::ShopOpenEnrollmentPeriodMaximum} months")
    end

    if (end_on - start_on) < HbxProfile::ShopPlanYearPeriodMinimum
     errors.add(:end_on, "plan year period is less than minumum: #{HbxProfile::ShopPlanYearPeriodMinimum} days")
    end

    if (end_on - start_on) > HbxProfile::ShopPlanYearPeriodMaximum
     errors.add(:end_on, "plan year period is greater than maximum: #{HbxProfile::ShopPlanYearPeriodMaximum} days")
    end
  end

end
