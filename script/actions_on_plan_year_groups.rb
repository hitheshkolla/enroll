FEIN = ['521963820', '311573701', '541392052', '521165054', '522019596', '522110168', '521771397', '521191969', '521272894', '208583706', '562332341', '530241123', '521136132', '530201498', '521949191', '521238374', '521976304', '521265622', '521385872', '204368380', '421545198', '522249589', '522356681', '521274001', '272387291', '942282759', '455054392', '300814595', '522318206', '521449994']
FEINS.each do |fein|
  organizations = Organization.where(fein: fein)

  if organizations.size != 1
    puts "something went wrong with employer: #{fein}"
  else
    organization = organizations.first
    plan_year = organization.employer_profile.plan_years.detect { |py| py.start_on.year == 2016}
  
    if plan_year.present? & if plan_year.may_cancel?
      bg_list = plan_year.benefit_groups.map(&:id)
      Family.where(:"households.hbx_enrollments.benefit_group_id".in => bg_list).each do |family|
        enrollments = family.active_household.hbx_enrollments.where(:benefit_group_id.in => bg_list).to_a
        if enrollments.present?
          puts "caneled 2016 enrollments for #{organization.legal_name}"
        end

        enrollments.each do |enrollment|
          enrollment.cancel_coverage! if enrollment.may_cancel_coverage?
        end
      end

      plan_year.cancel!
      puts 'moved 2016 plan year state to canceled'
    end

    if organization.employer_profile.is_coversion_employer?
      plan_year = organization.employer_profile.plan_years.detect { |py| py.start_on.year == 2015}
      if plan_year.present? && plan_year.may_conversion_expire?
        plan_year.conversion_expire!
        puts 'moved 2015 plan year state to migration expired'
      end
    end
  end
end
