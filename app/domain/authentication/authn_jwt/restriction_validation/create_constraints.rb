require 'command_class'

module Authentication
  module AuthnJwt
    module RestrictionValidation
      # Creating the needed constraints to check the host annotations:
      #   * NonEmptyConstraint - Checks at least one constraint is there
      #   * RequiredConstraint - Checks all the claims in "mandatory_claims" variable are in host annotations. If there
      #     is mapping for this claim it will convert it to relevant name
      #   * NonPermittedConstraint - Checks there are no standard claims [exp,iat,nbf,iss] in the host annotations
      CreateConstrains = CommandClass.new(
        dependencies: {
          non_permitted_constraint: Authentication::Constraints::NonPermittedConstraint.new(
            non_permitted: MANDATORY_CLAIMS_DENY_LIST
          ),
          required_constraint_class: Authentication::Constraints::RequiredConstraint,
          multiple_constraint_class: Authentication::Constraints::MultipleConstraint,
          not_empty_constraint: Authentication::Constraints::NotEmptyConstraint.new,
          fetch_mandatory_claims: Authentication::AuthnJwt::RestrictionValidation::FetchMandatoryClaims.new,
          fetch_mapping_claims_class: Authentication::AuthnJwt::RestrictionValidation::FetchMappingClaims,
          logger: Rails.logger
        },
        inputs: %i[authentication_parameters]
      ) do
        # These is command class so only call is called from outside. Other functions are needed here.
        # :reek:TooManyMethods
        def call
          @logger.info(LogMessages::Authentication::AuthnJwt::CreateContraintsFromPolicy.new)
          fetch_mandatory_claims
          fetch_mapping_claims
          map_mandatory_claims
          init_constraints_list
          add_non_empty_constraint
          add_required_constraint
          add_non_permitted_constraint
          create_multiple_constraint
          @logger.info(LogMessages::Authentication::AuthnJwt::CreatedConstraintsFromPolicy.new)
          multiple_constraint
        end

        private

        def init_constraints_list
          @constraints = []
        end

        def add_non_empty_constraint
          @constraints.append(@not_empty_constraint)
        end

        # Call should tell a story but
        # :reek:EnforcedStyleForLeadingUnderscores
        def fetch_mandatory_claims
          mandatory_claims
        end

        def map_mandatory_claims
          mapped_mandatory_claims
        end

        def mapped_mandatory_claims
          @mapped_mandatory_claims ||= mandatory_claims.map { |claim| convert_claim(claim) }
        end

        def convert_claim(claim)
          if mapping_claims.include?(claim)
            claim_reference = mapping_claims[claim]
            @logger.debug(LogMessages::Authentication::AuthnJwt::ConvertingClaimAccordingToMapping.new(claim, claim_reference))
            return claim_reference
          end
          claim
        end

        def fetch_mapping_claims
          mapping_claims
        end

        def add_required_constraint
          @constraints.append(required_constraint)
        end

        def add_non_permitted_constraint
          @constraints.append(@non_permitted_constraint)
        end

        def create_multiple_constraint
          multiple_constraint
        end

        def mandatory_claims
          @mandatory_claims ||= @fetch_mandatory_claims.call(
            authentication_parameters: @authentication_parameters
          )
        end

        def mapping_claims
          @mapping_claims ||= @fetch_mapping_claims_class.new.call(
            authentication_parameters: @authentication_parameters
          ).invert
        end

        def required_constraint
          @logger.info(LogMessages::Authentication::AuthnJwt::MandatoryClaimsToBeChecked.new(mapped_mandatory_claims))
          @required_constraint ||= @required_constraint_class.new(
            required: mapped_mandatory_claims
          )
        end

        def multiple_constraint
          @multiple_constraint ||= @multiple_constraint_class.new(*@constraints)
        end
      end
    end
  end
end