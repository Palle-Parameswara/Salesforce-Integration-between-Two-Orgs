/**
 * MWD26 demo — shared JSON wrappers for the Back Office integration.
 */
public class IntegrationRequestDTO {

    /** Payload sent to the Target Org. */
    public class OutboundRequest {
        public String requestName;
        public String customerEmail;
        public String requestDetails;
        public String sourceRecordId;
        public String sourceOrg;
    }

    /** Response shape returned by the Target Org. */
    public class TargetResponse {
        public Boolean success;
        public String externalRecordId;
        public String message;
    }
}
