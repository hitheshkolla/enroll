module Forms
  class PersonSignup
    include ActiveModel::Validations
    attr_accessor :id
    attr_accessor :person
    attr_accessor :first_name, :last_name, :email, :dob

    validates_presence_of :dob
    validates_presence_of :first_name
    validates_presence_of :last_name
    validates_presence_of :email

    class PersonAlreadyMatched < StandardError; end

    def initialize(attrs = {})
      assign_wrapper_attributes(attrs)
    end

    def assign_wrapper_attributes(attrs = {})
      attrs.each_pair do |k,v|
        self.send("#{k}=", v)
      end
    end

    def match_or_create_person
      matched_people = Person.where(
        first_name: regex_for(first_name),
        last_name: regex_for(last_name),
        dob: dob
        )
      
      if matched_people.count == 1
        raise PersonAlreadyMatched.new
      end

      self.person = Person.new({
        first_name: first_name,
        last_name: last_name,
        dob: dob
        })

      self.person.add_work_email(email)
    end

    def to_key
      @id
    end

    def dob=(val)
      @dob = Date.strptime(val,"%Y-%m-%d") rescue nil
    end

    def regex_for(str)
      Regexp.compile(Regexp.escape(str.to_s))
    end
  end
end
