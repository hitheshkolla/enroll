require File.join(Rails.root, "lib/mongoid_migration_task")

class UpdateInvalidBenefitGroupAssignmentForCensusEmployee < MongoidMigrationTask
	def migrate
     id = ENV["employee_role_id"].to_s
     employee_role = EmployeeRole.find(id)
     employee_role.census_employee.benefit_group_assignments.each do |bga|
      if bga.is_active? && !bga.valid?
        bga.is_active = false
        bga.aasm_state = "coverage_expired"
        bga.hbx_enrollment_id = nil
        bga.save
        puts "Updated Benefit group assignment for Employee with id: #{employee_role_id}" unless Rails.env.test?
      end
     end   
	end
end