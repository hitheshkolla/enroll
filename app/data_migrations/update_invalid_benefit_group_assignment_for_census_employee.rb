require File.join(Rails.root, "lib/mongoid_migration_task")

class UpdateInvalidBenefitGroupAssignmentForCensusEmployee < MongoidMigrationTask
  def migrate
    id = ENV["employee_role_id"].to_s
    employee_role = EmployeeRole.find(id)
    employee_role.census_employee.benefit_group_assignments.each do |bga|
      if bga.is_active? && !bga.valid?
        bga.update_attribute(:aasm_state, 'coverage_expired')
        bga.update_attribute(:is_active, false)
        bga.update_attribute(:hbx_enrollment_id, nil)
        puts "Updated Benefit group assignment for Employee with id: #{employee_role_id}" unless Rails.env.test?
      end
    end   
  end
end

