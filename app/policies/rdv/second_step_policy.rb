class Rdv::SecondStepPolicy < ApplicationPolicy
  def create?
    pro_and_belongs_to_record_organisation?
  end
end
