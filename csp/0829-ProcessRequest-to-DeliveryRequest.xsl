<?xml version="1.0" encoding="UTF-8"?>
<!-- 
Customization to support on-demand C62 for SDA Documents
- uses document info from AdditionalInfo
- support multiple C62 documents
- extend context 'VisitNumber' with C62 document number
- include serviceStart/Stop time for C62 and encounter summaries
- tweak title

TODO:
- legalAuthenticator
- author
 -->
<xsl:stylesheet version="1.0" 
xmlns:exsl="http://exslt.org/common"
xmlns:isc="http://extension-functions.intersystems.com" 
xmlns:xsl="http://www.w3.org/1999/XSL/Transform" 
exclude-result-prefixes="isc exsl">
	<xsl:output method="xml" indent="no" omit-xml-declaration="yes"/>
	<xsl:include href="../Variables.xsl"/>
	<xsl:include href="../../../../SDA3/Custom/Utility.xsl"/>

	<xsl:param name="affinityDomainOID"/>
	<xsl:param name="homeCommunityOID"/>

	<xsl:variable name="isOnDemand" select="/XDSbProcessRequest/Subscription/DeliveryType/text()='XDSb.OnDemand'"/>
	<xsl:variable name="isXACML" select="contains(/XDSbProcessRequest/Subscription/DeliveryOperation/text(),'XACML')"/>
	<xsl:variable name="contentScope" select="/XDSbProcessRequest/Subscription/ContentScope/text()"/>
	<xsl:variable name="transformType" select="/XDSbProcessRequest/Subscription/TransformationType/text()"/>
	<xsl:variable name="transformOption">
		<xsl:choose>
			<xsl:when test="$transformType='XSLT'">
				<xsl:value-of select="/XDSbProcessRequest/Subscription/XSLTFileSpec/text()"/>
			</xsl:when>
			<xsl:when test="$transformType='CUSTOM'">
				<xsl:value-of select="/XDSbProcessRequest/Subscription/TransformCustomOperation/text()"/>
			</xsl:when>
			<xsl:otherwise>
				<xsl:value-of select="/XDSbProcessRequest/Subscription/PatientReportId/text()"/>
			</xsl:otherwise>
		</xsl:choose>
	</xsl:variable>
	<xsl:variable name="documentCount" select="/XDSbProcessRequest/Document/AddUpdateHubRequest/AdditionalInfo/AdditionalInfoItem[@AdditionalInfoKey='Documents']/text()"/>

	<xsl:template match="/XDSbProcessRequest">
		<XMLMessage>
			<Name>
				<xsl:value-of select="$xdsbPushDeliveryRequest"/>
			</Name>

			<ContentStream>
				<Metadata>
					<Submission id="SS">
						<xsl:apply-templates mode="author" select="."/>
						<xsl:apply-templates mode="comments" select="."/>
						<xsl:apply-templates mode="contentTypeCode" select="."/>
						<xsl:apply-templates mode="intendedRecipient" select="."/>
						<xsl:apply-templates mode="patientId" select="."/>
						<xsl:apply-templates mode="sourceId" select="."/>
						<xsl:apply-templates mode="submissionTime" select="."/>
						<xsl:apply-templates mode="title" select="."/>
						<xsl:apply-templates mode="uniqueId" select="."/>
					</Submission>

					<!-- 
CUSTOM: add support for multiple C62's
standard code moved to new template
-->
					<xsl:for-each select="Document">
						<xsl:choose>
							<xsl:when test="$documentCount > 0 and $transformOption = 'Z-C62'">
								<xsl:apply-templates mode="Document" select=".">
									<xsl:with-param name="docPos" select="1"/>
								</xsl:apply-templates>
							</xsl:when>
							
							<xsl:when test="$transformOption = 'Z-CCDA-Encounter'">
								<xsl:apply-templates mode="Encounter" select=".">
								</xsl:apply-templates>
							</xsl:when>
							
							<xsl:otherwise>
								<xsl:apply-templates mode="Document" select=".">
									<xsl:with-param name="docID" select="DocumentId/text()"/>
									<xsl:with-param name="docUID" select="DocumentUniqueId/text()"/>
								</xsl:apply-templates>
							</xsl:otherwise>
						</xsl:choose>
					</xsl:for-each>

				</Metadata>
			</ContentStream>

			<AdditionalInfo>
				<xsl:apply-templates mode="additionalInfoItem" select="Subscription/EndPoint"/>
				<xsl:apply-templates mode="additionalInfoItem" select="Subscription/AccessGWEndPoint"/>
				<xsl:apply-templates mode="additionalInfoItem" select="Subscription/DeliveryOperation"/>
				<xsl:apply-templates mode="additionalInfoItem" select="Subscription/DeliveryType"/>
				<AdditionalInfoItem AdditionalInfoKey="USER:Roles">
					<xsl:value-of select="Subscription/RecipientRoles/text()"/>
				</AdditionalInfoItem>
				<xsl:choose>
					<xsl:when test="Document/SDA">
						<xsl:variable name="patientRoot" select="Document/SDA/Container/Patient"/>
						<AdditionalInfoItem AdditionalInfoKey="PatientMRN">
							<xsl:value-of select="$patientRoot/PatientNumbers/PatientNumber[NumberType='MRN']/Number/text()"/>
						</AdditionalInfoItem>
						<AdditionalInfoItem AdditionalInfoKey="PatientAA">
							<xsl:value-of select="$patientRoot/PatientNumbers/PatientNumber[NumberType='MRN']/Organization/Code/text()"/>
						</AdditionalInfoItem>
					</xsl:when>
					<xsl:when test="Document/AddUpdateHubRequest">
						<AdditionalInfoItem AdditionalInfoKey="PatientMRN">
							<xsl:value-of select="Document/AddUpdateHubRequest/MRN/text()"/>
						</AdditionalInfoItem>
						<AdditionalInfoItem AdditionalInfoKey="PatientAA">
							<xsl:value-of select="Document/AddUpdateHubRequest/AssigningAuthority/text()"/>
						</AdditionalInfoItem>
					</xsl:when>
				</xsl:choose>
			</AdditionalInfo>

			<xsl:if test="not($isOnDemand)">
				<StreamCollection>
					<xsl:apply-templates mode="mimeAttachment" select="Document"/>
				</StreamCollection>
			</xsl:if>

		</XMLMessage>
	</xsl:template>	

	<xsl:template mode="additionalInfoItem" match="*">
		<AdditionalInfoItem AdditionalInfoKey="{local-name()}">
			<xsl:value-of select="text()"/>
		</AdditionalInfoItem>
	</xsl:template>

	<xsl:template mode="mimeAttachment" match="Document">
		<MIMEAttachment>
			<ContentId>
				<xsl:value-of select="DocumentId/text()"/>
			</ContentId> 
			<ContentType>
				<xsl:apply-templates mode="mimeTypeValue" select="."/>
			</ContentType> 
			<ContentTransferEncoding>binary</ContentTransferEncoding> 
		</MIMEAttachment>
	</xsl:template>

	<!--
CUSTOM: moved standard code to separate template, 
- could be invoked multiple times for C62s
- generated doc ID's for C62 docs
-->
	<xsl:template mode="Document" match="Document">
		<xsl:param name="docID" select="concat('urn:uuid:',isc:evaluate('createUUID'))"/>
		<xsl:param name="docUID" select="isc:evaluate('uuid2oid',$docID)"/>
		<xsl:param name="docPos" select="0"/>

		<Association type="{$hasMember}" parent="SS" child="{$docID}"/>

		<Document id="{$docID}">
			<xsl:attribute name="type">
				<xsl:choose>
					<xsl:when test="$isOnDemand">OnDemand</xsl:when>
					<xsl:otherwise>Stable</xsl:otherwise>
				</xsl:choose>
			</xsl:attribute>

			<xsl:apply-templates mode="author" select="."/>
			<xsl:apply-templates mode="classCode" select=".">
				<xsl:with-param name="docPos" select="$docPos"/>
			</xsl:apply-templates>
			<xsl:apply-templates mode="comments" select="."/>
			<xsl:apply-templates mode="confidentialityCode" select="."/>
			<xsl:apply-templates mode="context" select=".">
				<xsl:with-param name="docPos" select="$docPos"/>
			</xsl:apply-templates>
			<xsl:apply-templates mode="creationTime" select="."/>
			<xsl:apply-templates mode="eventCodeList" select="."/>
			<xsl:apply-templates mode="formatCode" select=".">
				<xsl:with-param name="docPos" select="$docPos"/>
			</xsl:apply-templates>
			<xsl:apply-templates mode="healthcareFacilityTypeCode" select="."/>
			<xsl:apply-templates mode="languageCode" select="."/>
			<xsl:apply-templates mode="legalAuthenticator" select="."/>
			<xsl:apply-templates mode="mimeType" select="."/>
			<xsl:apply-templates mode="patientId" select="."/>
			<xsl:apply-templates mode="practiceSettingCode" select="."/>
			<xsl:apply-templates mode="serviceTimes" select=".">
				<xsl:with-param name="docPos" select="$docPos"/>
			</xsl:apply-templates>
			<xsl:apply-templates mode="sourcePatientId" select="."/>
			<xsl:apply-templates mode="sourcePatientInfo" select="."/>
			<xsl:apply-templates mode="title" select=".">
				<xsl:with-param name="docPos" select="$docPos"/>
			</xsl:apply-templates>
			<xsl:apply-templates mode="typeCode" select=".">
				<xsl:with-param name="docPos" select="$docPos"/>
			</xsl:apply-templates>
			<xsl:apply-templates mode="uniqueId" select=".">
				<xsl:with-param name="docUID" select="$docUID"/>
			</xsl:apply-templates>
		</Document>

		<!-- repeat for next one if more C62 docs -->
		<xsl:if test="$docPos > 0 and $documentCount > $docPos">
			<xsl:apply-templates mode="Document" select=".">
				<xsl:with-param name="docPos" select="$docPos+1"/>
			</xsl:apply-templates>
		</xsl:if>
	</xsl:template>

	
	<xsl:template mode="Encounter" match="Document">
		<xsl:for-each select="AddUpdateHubRequest/Encounters/AddUpdateHubEncounterInfo">
			<xsl:param name="docID" select="concat('urn:uuid:',isc:evaluate('createUUID'))"/>
			<xsl:param name="docUID" select="isc:evaluate('uuid2oid',$docID)"/>
			<xsl:param name="docPos" select="0"/>
			
			<Association type="{$hasMember}" parent="SS" child="{$docID}"/>

			<Document id="{$docID}">
				<xsl:attribute name="type">
					<xsl:choose>
						<xsl:when test="$isOnDemand">OnDemand</xsl:when>
						<xsl:otherwise>Stable</xsl:otherwise>
					</xsl:choose>
				</xsl:attribute>

				<!-- TODO: find out data needed for Encounter Author
				<xsl:apply-templates mode="encounter_author" select="."/>  -->
				
				<xsl:apply-templates mode="encounter_classCode" select=".">
					<xsl:with-param name="docPos" select="$docPos"/>
				</xsl:apply-templates>
				<xsl:apply-templates mode="encounter_comments" select="."/>
				<xsl:apply-templates mode="encounter_confidentialityCode" select="."/>
				<xsl:apply-templates mode="encounter_context" select=".">
					<xsl:with-param name="docPos" select="$docPos"/>
				</xsl:apply-templates>
				<xsl:apply-templates mode="encounter_creationTime" select="."/>
				<xsl:apply-templates mode="encounter_eventCodeList" select="."/>
				<xsl:apply-templates mode="encounter_formatCode" select=".">
					<xsl:with-param name="docPos" select="$docPos"/>
				</xsl:apply-templates>
				<xsl:apply-templates mode="encounter_healthcareFacilityTypeCode" select="."/>
				<xsl:apply-templates mode="encounter_languageCode" select="."/>
				<xsl:apply-templates mode="encounter_legalAuthenticator" select="."/>
				<xsl:apply-templates mode="encounter_mimeType" select="."/>
				<xsl:apply-templates mode="encounter_patientId" select="."/>
				<xsl:apply-templates mode="encounter_practiceSettingCode" select="."/>
				<xsl:apply-templates mode="encounter_serviceTimes" select=".">
					<xsl:with-param name="docPos" select="$docPos"/>
				</xsl:apply-templates>
				<xsl:apply-templates mode="encounter_sourcePatientId" select="."/>
				<xsl:apply-templates mode="encounter_sourcePatientInfo" select="."/>
				<xsl:apply-templates mode="encounter_title" select=".">
					<xsl:with-param name="docPos" select="$docPos"/>
				</xsl:apply-templates>
				<xsl:apply-templates mode="encounter_typeCode" select=".">
					<xsl:with-param name="docPos" select="$docPos"/>
				</xsl:apply-templates>
				<xsl:apply-templates mode="encounter_uniqueId" select=".">
					<xsl:with-param name="docUID" select="$docUID"/>
				</xsl:apply-templates>
			</Document>
		</xsl:for-each>
	</xsl:template>
	
	<!--

			XDSb Metadata Elements (alphabetical order)

-->

	<!-- author of SubmissionSet -->
	<xsl:template mode="author" match="XDSbProcessRequest">
		<xsl:call-template name="communityAuthor"/>
	</xsl:template>

	<!-- author of Document -->
	<xsl:template mode="author" match="Document">
		<xsl:choose>
			<xsl:when test="$isOnDemand">
				<xsl:call-template name="communityAuthor"/>
			</xsl:when>
			<xsl:otherwise>
				<xsl:apply-templates mode="personAuthor" select="SDA//Encounter/AttendingClinicians/CareProvider"/>
				<xsl:apply-templates mode="personAuthor" select="SDA//Encounter/AdmittingClinician"/>
				<xsl:apply-templates mode="personAuthor" select="SDA//Encounter/EnteredBy"/>
			</xsl:otherwise>
		</xsl:choose>
	</xsl:template>
	
	<!-- author of Encounter -->
	<xsl:template mode="encounter_author" match="Document">
		<xsl:choose>
			<xsl:when test="$isOnDemand">
				<xsl:call-template name="communityAuthor"/>
			</xsl:when>
			<xsl:otherwise>
				<xsl:apply-templates mode="personAuthor" select="SDA//Encounter/AttendingClinicians/CareProvider"/>
				<xsl:apply-templates mode="personAuthor" select="SDA//Encounter/AdmittingClinician"/>
				<xsl:apply-templates mode="personAuthor" select="SDA//Encounter/EnteredBy"/>
			</xsl:otherwise>
		</xsl:choose>
	</xsl:template>

	<!-- classCode of Document-->
	<!-- CUSTOM: same as the typeCode -->
	<xsl:template mode="classCode" match="Document">
		<xsl:param name="docPos" select="0"/>

		<!-- Default using valid NIST code for connect-a-thon and demo -->
		<!-- RHIO's may override by adding config keys to the registry -->
		<xsl:variable name="config" select="isc:evaluate('getCodedEntryConfig','classCode',$contentScope,$transformType,$transformOption)"/>
		<xsl:call-template name="insertCode">
			<xsl:with-param name="name" select="'ClassCode'"/>
			<xsl:with-param name="code">
				<xsl:choose>
					<xsl:when test="$config">
						<xsl:value-of select="$config"/>
					</xsl:when>
					<xsl:when test="$isXACML">57017-6^Privacy Policy^LOINC</xsl:when>
					<xsl:when test="$docPos > 0">
						<xsl:apply-templates mode="getDocLOINC" select=".">
							<xsl:with-param name="docPos" select="$docPos"/>
						</xsl:apply-templates>
					</xsl:when>
					<xsl:when test="$contentScope = 'Enc'">
						<xsl:call-template name="toLOINC">
							<xsl:with-param name="type" select="'Encounter'"/>
						</xsl:call-template>
					</xsl:when>
					<xsl:when test="$contentScope = 'MRN'">History and Physical^History and Physical^Connect-a-thon classCodes</xsl:when>
					<xsl:when test="$contentScope = 'MPI'">
						<xsl:call-template name="toLOINC">
							<xsl:with-param name="type" select="'Patient'"/>
						</xsl:call-template>
					</xsl:when>
					<xsl:otherwise>Targeted history and physical^Targeted history and physical^Connect-a-thon classCodes</xsl:otherwise>
				</xsl:choose>
			</xsl:with-param>
		</xsl:call-template>
	</xsl:template>

	<xsl:template mode="encounter_classCode" match="AddUpdateHubEncounterInfo">
		<xsl:param name="docPos" select="0"/>

		<!-- Default using valid NIST code for connect-a-thon and demo -->
		<!-- RHIO's may override by adding config keys to the registry -->
		<xsl:variable name="config" select="isc:evaluate('getCodedEntryConfig','classCode',$contentScope,$transformType,$transformOption)"/>
		<xsl:call-template name="insertCode">
			<xsl:with-param name="name" select="'ClassCode'"/>
			<xsl:with-param name="code">
				<xsl:choose>
					<xsl:when test="$contentScope = 'Enc'">
						<xsl:call-template name="toLOINC">
							<xsl:with-param name="type" select="'Encounter'"/>
						</xsl:call-template>
					</xsl:when>
					<xsl:otherwise>Targeted history and physical^Targeted history and physical^Connect-a-thon classCodes</xsl:otherwise>
				</xsl:choose>
			</xsl:with-param>
		</xsl:call-template>
	</xsl:template>


	<!-- comments for SubmissionSet-->
	<xsl:template mode="comments" match="XDSbProcessRequest">
		<!-- By default, no comments for submission -->
	</xsl:template>

	<!-- comments for Document -->
	<xsl:template mode="comments" match="Document">
		<Comments>
			<xsl:if test="not($isXACML)">
				<xsl:choose>
					<xsl:when test="SDA">
						<xsl:value-of select="SDA/Container/EventDescription/text()"/>
					</xsl:when>
					<!--  CUSTOM: removed -->
					<!-- <xsl:when test="AddUpdateHubRequest"><xsl:value-of select="AddUpdateHubRequest/EventType/text()"/></xsl:when> -->
				</xsl:choose>
			</xsl:if>
		</Comments>
	</xsl:template>

	<!-- comments for Encounter -->
	<xsl:template mode="encounter_comments" match="AddUpdateHubEncounterInfo">
		<Comments>
		</Comments>
	</xsl:template>

	<!-- confidentialityCode for Document -->
	<xsl:template mode="confidentialityCode" match="Document">
		<!-- Default using valid NIST code for connect-a-thon and demo -->
		<!-- RHIO's may override by adding config keys to the registry -->
		<xsl:variable name="config" select="isc:evaluate('getCodedEntryConfig','confidentialityCode',$contentScope,$transformType,$transformOption)"/>
		<xsl:call-template name="insertCode">
			<xsl:with-param name="name" select="'ConfidentialityCode'"/>
			<xsl:with-param name="code">
				<xsl:choose>
					<xsl:when test="$config">
						<xsl:value-of select="$config"/>
					</xsl:when>
					<xsl:otherwise>N^Normal^2.16.840.1.113883.5.25</xsl:otherwise>
				</xsl:choose>
			</xsl:with-param>
		</xsl:call-template>
	</xsl:template>

	<!-- confidentialityCode for Encounter -->
	<xsl:template mode="encounter_confidentialityCode" match="AddUpdateHubEncounterInfo">
		<!-- Default using valid NIST code for connect-a-thon and demo -->
		<!-- RHIO's may override by adding config keys to the registry -->
		<xsl:variable name="config" select="isc:evaluate('getCodedEntryConfig','confidentialityCode',$contentScope,$transformType,$transformOption)"/>
		<xsl:call-template name="insertCode">
			<xsl:with-param name="name" select="'ConfidentialityCode'"/>
			<xsl:with-param name="code">
				<xsl:choose>
					<xsl:when test="$config">
						<xsl:value-of select="$config"/>
					</xsl:when>
					<xsl:otherwise>N^Normal^2.16.840.1.113883.5.25</xsl:otherwise>
				</xsl:choose>
			</xsl:with-param>
		</xsl:call-template>
	</xsl:template>

	<!-- contentTypeCode for SubmissionSet  -->
	<!-- CUSTOM: use the same value as the first document typeCode -->
	<xsl:template mode="contentTypeCode" match="XDSbProcessRequest">

		<!-- Default using valid NIST code for connect-a-thon and demo -->
		<!-- RHIO's may override by adding config keys to the registry -->
		<xsl:variable name="config" select="isc:evaluate('getCodedEntryConfig','contentTypeCode',$contentScope,$transformType,$transformOption)"/>
		<xsl:call-template name="insertCode">
			<xsl:with-param name="name" select="'ContentTypeCode'"/>
			<xsl:with-param name="code">
				<xsl:choose>
					<xsl:when test="$config">
						<xsl:value-of select="$config"/>
					</xsl:when>
					<xsl:when test="$isXACML">57017-6^Privacy Policy^LOINC</xsl:when>
					<xsl:when test="$documentCount > 0 and $transformOption = 'Z-C62'">
						<xsl:apply-templates mode="getDocLOINC" select="Document[1]">
							<xsl:with-param name="docPos" select="1"/>
						</xsl:apply-templates>
					</xsl:when>
					<xsl:when test="$contentScope = 'Enc'">
						<xsl:call-template name="toLOINC">
							<xsl:with-param name="type" select="'Encounter'"/>
						</xsl:call-template>
					</xsl:when>
					<xsl:when test="$contentScope = 'MRN'">History and Physical^History and Physical^Connect-a-thon contentTypeCodes</xsl:when>
					<xsl:when test="$contentScope = 'MPI'">
						<xsl:call-template name="toLOINC">
							<xsl:with-param name="type" select="'Patient'"/>
						</xsl:call-template>
					</xsl:when>
					<xsl:otherwise>Targeted history and physical^Targeted history and physical^Connect-a-thon contentTypeCodes</xsl:otherwise>
				</xsl:choose>
			</xsl:with-param>
		</xsl:call-template>
	</xsl:template>

	<!-- context for Document -->
	<!-- CUSTOM: include doc num for C62 -->
	<xsl:template mode="context" match="Document">
		<xsl:param name="docPos" select="0"/>

		<!-- Create context for this document use for on-demand creation and stable replacement -->
		<!-- Message scope does not have a context, and thus will never issue a replace -->
		<xsl:if test="$contentScope != 'Msg'">
			<Context>
				<xsl:copy-of select="../MPIID"/>
				<xsl:if test="$contentScope != 'MPI'">
					<xsl:copy-of select="../MRN"/>
					<xsl:copy-of  select="../AssigningAuthority"/>
					<xsl:copy-of  select="../Facility"/>
				</xsl:if>
				<xsl:if test="$contentScope = 'Enc'">
					<xsl:variable name="docEnc">
						<xsl:choose>
							<xsl:when test="$docPos > 0">
								<xsl:apply-templates mode="getDocProp" select=".">
									<xsl:with-param name="docPos" select="$docPos"/>
									<xsl:with-param name="docProp" select="'Encounter'"/>
								</xsl:apply-templates>
							</xsl:when>
							<xsl:otherwise/>
						</xsl:choose>
					</xsl:variable>
					<xsl:variable name="encNo">
						<xsl:choose>
							<xsl:when test="string-length($docEnc) > 0">
								<xsl:value-of select="$docEnc"/>
							</xsl:when>
							<xsl:when test="AddUpdateHubRequest">
								<xsl:value-of select="EncounterNumber/text()" />
							</xsl:when>
							<xsl:when test="SDA//Encounter/EncounterNumber/text()">
								<xsl:value-of select="SDA//Encounter/EncounterNumber/text()" />
							</xsl:when>
							<xsl:otherwise>
								<xsl:value-of select="SDA//Encounter/ExternalId/text()" />
							</xsl:otherwise>
						</xsl:choose>
					</xsl:variable>
					<xsl:variable name="docNum">
						<xsl:choose>
							<xsl:when test="$docPos > 0">
								<xsl:apply-templates mode="getDocProp" select=".">
									<xsl:with-param name="docPos" select="$docPos"/>
									<xsl:with-param name="docProp" select="'Number'"/>
								</xsl:apply-templates>
							</xsl:when>
							<xsl:otherwise/>
						</xsl:choose>
					</xsl:variable>
					<VisitNumber>
						<xsl:choose>
							<xsl:when test="string-length($docNum>0)"><xsl:value-of select="concat($encNo,'|',$docNum)"/>
							</xsl:when>
							<xsl:otherwise>
								<xsl:value-of select="$encNo"/>
							</xsl:otherwise>
						</xsl:choose>
					</VisitNumber>
				</xsl:if>
				<TransformType>
					<xsl:value-of select="$transformType"/>
				</TransformType>
				<TransformOption>
					<xsl:value-of select="$transformOption"/>
				</TransformOption>
				<ServiceId>
					<xsl:value-of select="../Subscription/EndPoint/text()"/>
				</ServiceId>
				<TransProfile>
					<xsl:value-of select="../Subscription/TransProfile/text()"/>
				</TransProfile>
			</Context>
		</xsl:if>
	</xsl:template>

	<!-- context for Encounter -->
	<!-- CUSTOM: include doc num for C62 -->
	<xsl:template mode="encounter_context" match="AddUpdateHubEncounterInfo">
		<xsl:param name="docPos" select="0"/>

		<!-- Create context for this document use for on-demand creation and stable replacement -->
		<!-- Message scope does not have a context, and thus will never issue a replace -->
		<xsl:if test="$contentScope != 'Msg'">
			<Context>
				<xsl:copy-of select="../../../../MPIID"/>

				<xsl:if test="$contentScope != 'MPI'">
					<xsl:copy-of select="../../../../MRN"/>
					<xsl:copy-of  select="../../../../AssigningAuthority"/>
					<xsl:copy-of  select="../../../../Facility"/>
				</xsl:if>

				<xsl:if test="$contentScope = 'Enc'">
					<xsl:variable name="encNo">
						<xsl:choose>
							<xsl:when test="EncounterNumber">
								<xsl:value-of select="EncounterNumber/text()" />
							</xsl:when>
							<!-- Commented out for testing purposes:
							<xsl:when test="SDA//Encounter/EncounterNumber/text()">
								<xsl:value-of select="SDA//Encounter/EncounterNumber/text()" />
							</xsl:when>
							<xsl:otherwise>
								<xsl:value-of select="SDA//Encounter/ExternalId/text()" />
							</xsl:otherwise> -->
							<xsl:otherwise>
							</xsl:otherwise>
						</xsl:choose>
					</xsl:variable>
					<xsl:variable name="docNum">
						<xsl:choose>
							<xsl:when test="$docPos > 0">
								<!--<xsl:apply-templates mode="getDocProp" select=".">
									<xsl:with-param name="docPos" select="$docPos"/>
									<xsl:with-param name="docProp" select="'Number'"/>
								</xsl:apply-templates>-->
							</xsl:when>
							<xsl:otherwise/>
						</xsl:choose>
					</xsl:variable>
					<VisitNumber>
						<xsl:value-of select="$encNo"/>
					</VisitNumber>
				</xsl:if>
				<TransformType>
					<xsl:value-of select="$transformType"/>
				</TransformType>
				<TransformOption>
					<xsl:value-of select="$transformOption"/>
				</TransformOption>
				<ServiceId>
					<!-- <xsl:value-of select="../Subscription/EndPoint/text()"/> -->
				</ServiceId>
				<TransProfile>
					<!-- <xsl:value-of select="../Subscription/TransProfile/text()"/>  -->
				</TransProfile>
			</Context>
		</xsl:if>
	</xsl:template>


	<!-- creationTime of Document -->
	<xsl:template mode="creationTime" match="Document">
		<xsl:if test="not($isOnDemand)">
			<xsl:variable name="enteredOn" select="SDA//Encounter/EnteredOn/text()"/>
			<CreationTime>
				<xsl:choose>
					<xsl:when test="$enteredOn">
						<xsl:value-of select="translate($enteredOn,'-:TZ ','')"/>
					</xsl:when>
					<xsl:otherwise>
						<xsl:value-of select="isc:evaluate('createHL7Timestamp')"/>
					</xsl:otherwise>
				</xsl:choose>
			</CreationTime>
		</xsl:if>
	</xsl:template>
	
	<!-- creationTime of Encounter -->
	<xsl:template mode="encounter_creationTime" match="AddUpdateHubEncounterInfo">
		<xsl:if test="not($isOnDemand)">
			<xsl:variable name="enteredOn" select="FromTime/text()"/>
			<CreationTime>
				<xsl:choose>
					<xsl:when test="$enteredOn">
						<xsl:value-of select="translate($enteredOn,'-:TZ ','')"/>
					</xsl:when>
					<xsl:otherwise>
						<xsl:value-of select="isc:evaluate('createHL7Timestamp')"/>
					</xsl:otherwise>
				</xsl:choose>
			</CreationTime>
		</xsl:if>
	</xsl:template>

	<!-- eventCodeList for Document -->
	<xsl:template mode="eventCodeList" match="Document">
		<!-- The NIST codes only specify to radiology procedures -->
		<!-- Default no event codes since context is so broad    -->
		<!-- RHIO's may override by customizing this XSL -->
	</xsl:template>
	
	<!-- eventCodeList for Encounter -->
	<xsl:template mode="encounter_eventCodeList" match="AddUpdateHubEncounterInfo">
		<!-- The NIST codes only specify to radiology procedures -->
		<!-- Default no event codes since context is so broad    -->
		<!-- RHIO's may override by customizing this XSL -->
	</xsl:template>

	<!-- formatCode for Document -->
	<xsl:template mode="formatCode" match="Document">
		<!-- Default using valid NIST code for connect-a-thon and demo -->
		<!-- RHIO's may override by adding config keys to the registry -->
		<!-- TODO: Figure out the right default codes for XSLT xforms -->
		<xsl:variable name="config" select="isc:evaluate('getCodedEntryConfig','formatCode',$contentScope,$transformType,$transformOption)"/>
		<xsl:call-template name="insertCode">
			<xsl:with-param name="name" select="'FormatCode'"/>
			<xsl:with-param name="code">
				<xsl:choose>
					<xsl:when test="$config">
						<xsl:value-of select="$config"/>
					</xsl:when>
					<xsl:when test="$isXACML">urn:nhin:names:acp:XACML^XACML Policy^1.3.6.1.4.1.19376.1.2.3</xsl:when>
					<xsl:when test="$transformType='PDF'">PDF^PDF^Connect-a-thon formatCodes</xsl:when>
					<xsl:when test="$transformType='XSLT'">
						<xsl:choose>
							<xsl:when test="$transformOption='C32v25'">urn:ihe:pcc:xphr:2007^Exchange of Personal Health Records^IHE PCC</xsl:when>
							<xsl:when test="$transformOption='C37v23'">urn:ihe:lab:xd-lab:2008^CDA Laboratory Report^IHE PCC</xsl:when>
							<xsl:when test="$transformOption='C48.1v25'">urn:ihe:pcc:xds-ms:2007^Medical Summaries^IHE PCC</xsl:when>
							<xsl:when test="$transformOption='C48.2v25'">urn:ihe:pcc:xds-ms:2007^Medical Summaries^IHE PCC</xsl:when>
							<xsl:when test="$transformOption='CCR'">CCR V1.0^CCR V1.0^Connect-a-thon formatCodes</xsl:when>
							<xsl:when test="$transformOption='CCDA-CCD'">urn:hl7-org:sdwg:ccda-structuredBody:1.1^Consolidated CDA R1.1 Structured Body Document^1.3.6.1.4.1.19376.1.2.3</xsl:when>
							<xsl:when test="$transformOption='CCDA-ClinicalSummary'">urn:hl7-org:sdwg:ccda-structuredBody:1.1^Consolidated CDA R1.1 Structured Body Document^1.3.6.1.4.1.19376.1.2.3</xsl:when>
							<xsl:when test="$transformOption='CCDA-ExportAmbulatory'">urn:hl7-org:sdwg:ccda-structuredBody:1.1^Consolidated CDA R1.1 Structured Body Document^1.3.6.1.4.1.19376.1.2.3</xsl:when>
							<xsl:when test="$transformOption='CCDA-ExportInpatient'">urn:hl7-org:sdwg:ccda-structuredBody:1.1^Consolidated CDA R1.1 Structured Body Document^1.3.6.1.4.1.19376.1.2.3</xsl:when>
							<xsl:when test="$transformOption='CCDA-ExportSummary'">urn:hl7-org:sdwg:ccda-structuredBody:1.1^Consolidated CDA R1.1 Structured Body Document^1.3.6.1.4.1.19376.1.2.3</xsl:when>
							<xsl:when test="$transformOption='CCDA-TocRefAmbulatory'">urn:hl7-org:sdwg:ccda-structuredBody:1.1^Consolidated CDA R1.1 Structured Body Document^1.3.6.1.4.1.19376.1.2.3</xsl:when>
							<xsl:when test="$transformOption='CCDA-TocRefInpatient'">urn:hl7-org:sdwg:ccda-structuredBody:1.1^Consolidated CDA R1.1 Structured Body Document^1.3.6.1.4.1.19376.1.2.3</xsl:when>
							<xsl:when test="$transformOption='CCDA-TocRefSummary'">urn:hl7-org:sdwg:ccda-structuredBody:1.1^Consolidated CDA R1.1 Structured Body Document^1.3.6.1.4.1.19376.1.2.3</xsl:when>
							<xsl:when test="$transformOption='CCDA-VDTAmbulatory'">urn:hl7-org:sdwg:ccda-structuredBody:1.1^Consolidated CDA R1.1 Structured Body Document^1.3.6.1.4.1.19376.1.2.3</xsl:when>
							<xsl:when test="$transformOption='CCDA-VDTInpatient'">urn:hl7-org:sdwg:ccda-structuredBody:1.1^Consolidated CDA R1.1 Structured Body Document^1.3.6.1.4.1.19376.1.2.3</xsl:when>
							<xsl:when test="$transformOption='CCDA-CON'">urn:hl7-org:sdwg:ccda-structuredBody:1.1^Consolidated CDA R1.1 Structured Body Document^1.3.6.1.4.1.19376.1.2.3</xsl:when>
							<xsl:when test="$transformOption='CCDA-DIR'">urn:hl7-org:sdwg:ccda-structuredBody:1.1^Consolidated CDA R1.1 Structured Body Document^1.3.6.1.4.1.19376.1.2.3</xsl:when>
							<xsl:when test="$transformOption='CCDA-DSC'">urn:hl7-org:sdwg:ccda-structuredBody:1.1^Consolidated CDA R1.1 Structured Body Document^1.3.6.1.4.1.19376.1.2.3</xsl:when>
							<xsl:when test="$transformOption='CCDA-HNP'">urn:hl7-org:sdwg:ccda-structuredBody:1.1^Consolidated CDA R1.1 Structured Body Document^1.3.6.1.4.1.19376.1.2.3</xsl:when>
							<xsl:when test="$transformOption='CCDA-SRG'">urn:hl7-org:sdwg:ccda-structuredBody:1.1^Consolidated CDA R1.1 Structured Body Document^1.3.6.1.4.1.19376.1.2.3</xsl:when>
							<xsl:when test="$transformOption='CCDA-PRC'">urn:hl7-org:sdwg:ccda-structuredBody:1.1^Consolidated CDA R1.1 Structured Body Document^1.3.6.1.4.1.19376.1.2.3</xsl:when>
							<xsl:when test="$transformOption='CCDA-PRG'">urn:hl7-org:sdwg:ccda-structuredBody:1.1^Consolidated CDA R1.1 Structured Body Document^1.3.6.1.4.1.19376.1.2.3</xsl:when>
							<xsl:when test="$transformOption='CCDA-UNS'">urn:hl7-org:sdwg:ccda-nonXMLBody:1.1^Consolidated CDA R1.1 Unstructured Document^1.3.6.1.4.1.19376.1.2.3</xsl:when>
							<xsl:when test="$transformOption='AU-DSCv34'">1.2.36.1.2001.1001.101.100.1002.4^Discharge Summary Document^NEHTA</xsl:when>
							<xsl:when test="$transformOption='AU-EVTv12'">1.2.36.1.2001.1001.101.100.1002.136^Event Summary Document^NEHTA</xsl:when>
							<xsl:when test="$transformOption='AU-REFv22'">1.2.36.1.2001.1001.101.100.1002.2^Referral Document^NEHTA</xsl:when>
							<xsl:when test="$transformOption='AU-SHSv13'">1.2.36.1.2001.1001.101.100.1002.120^Shared Health Summary Document^NEHTA</xsl:when>
							<xsl:when test="$transformOption='Z-CCDA-Patient'">urn:hl7-org:sdwg:ccda-structuredBody:1.1^Consolidated CDA R1.1 Structured Body Document^1.3.6.1.4.1.19376.1.2.3</xsl:when>
							<xsl:when test="$transformOption='Z-CCDA-Encounter'">urn:hl7-org:sdwg:ccda-structuredBody:1.1^Consolidated CDA R1.1 Structured Body Document^1.3.6.1.4.1.19376.1.2.3</xsl:when>
							<xsl:when test="$transformOption='Z-C62'">urn:ihe:iti:xds-sd:text:2008^Scanned Documents Text^1.3.6.1.4.1.19376.1.2.3</xsl:when>
							<xsl:when test="$transformOption='Z-VA-CCDAv21-CCD'">urn:hl7-org:sdwg:ccda-structuredBody:2.1^Consolidated CDA R2.1 Structured Body Document^1.3.6.1.4.1.19376.1.2.3</xsl:when>							
 							<xsl:when test="$transformOption='Z-VA-C32V25'">urn:ihe:pcc:xphr:2007^Exchange of Personal Health Records^IHE PCC</xsl:when>
							<xsl:otherwise>2.16.840.1.113883.10.20.1^HL7 CCD Document^2.16.840.1.113883.3.88</xsl:otherwise>
						</xsl:choose>
					</xsl:when>
					<xsl:otherwise>TEXT^TEXT^Connect-a-thon formatCodes</xsl:otherwise>
				</xsl:choose>
			</xsl:with-param>
		</xsl:call-template>
	</xsl:template>

	<!-- formatCode for Encounter -->
	<xsl:template mode="encounter_formatCode" match="AddUpdateHubEncounterInfo">
		<!-- Default using valid NIST code for connect-a-thon and demo -->
		<!-- RHIO's may override by adding config keys to the registry -->
		<!-- TODO: Figure out the right default codes for XSLT xforms -->
		<xsl:variable name="config" select="isc:evaluate('getCodedEntryConfig','formatCode',$contentScope,$transformType,$transformOption)"/>
		<xsl:call-template name="insertCode">
			<xsl:with-param name="name" select="'FormatCode'"/>
			<xsl:with-param name="code">
				<xsl:choose>
					<xsl:when test="$config">
						<xsl:value-of select="$config"/>
					</xsl:when>
					<xsl:when test="$isXACML">urn:nhin:names:acp:XACML^XACML Policy^1.3.6.1.4.1.19376.1.2.3</xsl:when>
					<xsl:when test="$transformType='PDF'">PDF^PDF^Connect-a-thon formatCodes</xsl:when>
					<xsl:when test="$transformType='XSLT'">
						<xsl:choose>
							<xsl:when test="$transformOption='C32v25'">urn:ihe:pcc:xphr:2007^Exchange of Personal Health Records^IHE PCC</xsl:when>
							<xsl:when test="$transformOption='C37v23'">urn:ihe:lab:xd-lab:2008^CDA Laboratory Report^IHE PCC</xsl:when>
							<xsl:when test="$transformOption='C48.1v25'">urn:ihe:pcc:xds-ms:2007^Medical Summaries^IHE PCC</xsl:when>
							<xsl:when test="$transformOption='C48.2v25'">urn:ihe:pcc:xds-ms:2007^Medical Summaries^IHE PCC</xsl:when>
							<xsl:when test="$transformOption='CCR'">CCR V1.0^CCR V1.0^Connect-a-thon formatCodes</xsl:when>
							<xsl:when test="$transformOption='CCDA-CCD'">urn:hl7-org:sdwg:ccda-structuredBody:1.1^Consolidated CDA R1.1 Structured Body Document^1.3.6.1.4.1.19376.1.2.3</xsl:when>
							<xsl:when test="$transformOption='CCDA-ClinicalSummary'">urn:hl7-org:sdwg:ccda-structuredBody:1.1^Consolidated CDA R1.1 Structured Body Document^1.3.6.1.4.1.19376.1.2.3</xsl:when>
							<xsl:when test="$transformOption='CCDA-ExportAmbulatory'">urn:hl7-org:sdwg:ccda-structuredBody:1.1^Consolidated CDA R1.1 Structured Body Document^1.3.6.1.4.1.19376.1.2.3</xsl:when>
							<xsl:when test="$transformOption='CCDA-ExportInpatient'">urn:hl7-org:sdwg:ccda-structuredBody:1.1^Consolidated CDA R1.1 Structured Body Document^1.3.6.1.4.1.19376.1.2.3</xsl:when>
							<xsl:when test="$transformOption='CCDA-ExportSummary'">urn:hl7-org:sdwg:ccda-structuredBody:1.1^Consolidated CDA R1.1 Structured Body Document^1.3.6.1.4.1.19376.1.2.3</xsl:when>
							<xsl:when test="$transformOption='CCDA-TocRefAmbulatory'">urn:hl7-org:sdwg:ccda-structuredBody:1.1^Consolidated CDA R1.1 Structured Body Document^1.3.6.1.4.1.19376.1.2.3</xsl:when>
							<xsl:when test="$transformOption='CCDA-TocRefInpatient'">urn:hl7-org:sdwg:ccda-structuredBody:1.1^Consolidated CDA R1.1 Structured Body Document^1.3.6.1.4.1.19376.1.2.3</xsl:when>
							<xsl:when test="$transformOption='CCDA-TocRefSummary'">urn:hl7-org:sdwg:ccda-structuredBody:1.1^Consolidated CDA R1.1 Structured Body Document^1.3.6.1.4.1.19376.1.2.3</xsl:when>
							<xsl:when test="$transformOption='CCDA-VDTAmbulatory'">urn:hl7-org:sdwg:ccda-structuredBody:1.1^Consolidated CDA R1.1 Structured Body Document^1.3.6.1.4.1.19376.1.2.3</xsl:when>
							<xsl:when test="$transformOption='CCDA-VDTInpatient'">urn:hl7-org:sdwg:ccda-structuredBody:1.1^Consolidated CDA R1.1 Structured Body Document^1.3.6.1.4.1.19376.1.2.3</xsl:when>
							<xsl:when test="$transformOption='CCDA-CON'">urn:hl7-org:sdwg:ccda-structuredBody:1.1^Consolidated CDA R1.1 Structured Body Document^1.3.6.1.4.1.19376.1.2.3</xsl:when>
							<xsl:when test="$transformOption='CCDA-DIR'">urn:hl7-org:sdwg:ccda-structuredBody:1.1^Consolidated CDA R1.1 Structured Body Document^1.3.6.1.4.1.19376.1.2.3</xsl:when>
							<xsl:when test="$transformOption='CCDA-DSC'">urn:hl7-org:sdwg:ccda-structuredBody:1.1^Consolidated CDA R1.1 Structured Body Document^1.3.6.1.4.1.19376.1.2.3</xsl:when>
							<xsl:when test="$transformOption='CCDA-HNP'">urn:hl7-org:sdwg:ccda-structuredBody:1.1^Consolidated CDA R1.1 Structured Body Document^1.3.6.1.4.1.19376.1.2.3</xsl:when>
							<xsl:when test="$transformOption='CCDA-SRG'">urn:hl7-org:sdwg:ccda-structuredBody:1.1^Consolidated CDA R1.1 Structured Body Document^1.3.6.1.4.1.19376.1.2.3</xsl:when>
							<xsl:when test="$transformOption='CCDA-PRC'">urn:hl7-org:sdwg:ccda-structuredBody:1.1^Consolidated CDA R1.1 Structured Body Document^1.3.6.1.4.1.19376.1.2.3</xsl:when>
							<xsl:when test="$transformOption='CCDA-PRG'">urn:hl7-org:sdwg:ccda-structuredBody:1.1^Consolidated CDA R1.1 Structured Body Document^1.3.6.1.4.1.19376.1.2.3</xsl:when>
							<xsl:when test="$transformOption='CCDA-UNS'">urn:hl7-org:sdwg:ccda-nonXMLBody:1.1^Consolidated CDA R1.1 Unstructured Document^1.3.6.1.4.1.19376.1.2.3</xsl:when>
							<xsl:when test="$transformOption='AU-DSCv34'">1.2.36.1.2001.1001.101.100.1002.4^Discharge Summary Document^NEHTA</xsl:when>
							<xsl:when test="$transformOption='AU-EVTv12'">1.2.36.1.2001.1001.101.100.1002.136^Event Summary Document^NEHTA</xsl:when>
							<xsl:when test="$transformOption='AU-REFv22'">1.2.36.1.2001.1001.101.100.1002.2^Referral Document^NEHTA</xsl:when>
							<xsl:when test="$transformOption='AU-SHSv13'">1.2.36.1.2001.1001.101.100.1002.120^Shared Health Summary Document^NEHTA</xsl:when>
							<xsl:when test="$transformOption='Z-CCDA-Patient'">urn:hl7-org:sdwg:ccda-structuredBody:1.1^Consolidated CDA R1.1 Structured Body Document^1.3.6.1.4.1.19376.1.2.3</xsl:when>
							<xsl:when test="$transformOption='Z-CCDA-Encounter'">urn:hl7-org:sdwg:ccda-structuredBody:1.1^Consolidated CDA R1.1 Structured Body Document^1.3.6.1.4.1.19376.1.2.3</xsl:when>
							<xsl:when test="$transformOption='Z-C62'">urn:ihe:iti:xds-sd:text:2008^Scanned Documents Text^1.3.6.1.4.1.19376.1.2.3</xsl:when>
							<xsl:otherwise>2.16.840.1.113883.10.20.1^HL7 CCD Document^2.16.840.1.113883.3.88</xsl:otherwise>
						</xsl:choose>
					</xsl:when>
					<xsl:otherwise>TEXT^TEXT^Connect-a-thon formatCodes</xsl:otherwise>
				</xsl:choose>
			</xsl:with-param>
		</xsl:call-template>
	</xsl:template>


	<!-- healthcareFacilityTypeCode for Document -->
	<!-- CUSTOM: default to Military Hospital -->
	<xsl:template mode="healthcareFacilityTypeCode" match="Document">
		<!-- Default using valid NIST code for connect-a-thon and demo -->
		<!-- RHIO's may override by adding config keys to the registry -->
		<!-- TODO: enhance this to look at EncounterType node -->
		<xsl:variable name="config" select="isc:evaluate('getCodedEntryConfig','healthcareFacilityTypeCode',../Facility/text())"/>

		<xsl:call-template name="insertCode">
			<xsl:with-param name="name" select="'HealthcareFacilityTypeCode'"/>
			<xsl:with-param name="code">
				<xsl:choose>
					<xsl:when test="$config">
						<xsl:value-of select="$config"/>
					</xsl:when>
					<xsl:when test="$isXACML">385432009^Not Applicable^SNOMED</xsl:when>
					<xsl:otherwise>MHSP^Military Hospital^2.16.840.1.113883.5.11</xsl:otherwise>
				</xsl:choose>
			</xsl:with-param>
		</xsl:call-template>
	</xsl:template>


	<!-- healthcareFacilityTypeCode for Encounter -->
	<!-- CUSTOM: default to Military Hospital -->
	<xsl:template mode="encounter_healthcareFacilityTypeCode" match="AddUpdateHubEncounterInfo">
		<!-- Default using valid NIST code for connect-a-thon and demo -->
		<!-- RHIO's may override by adding config keys to the registry -->
		<!-- TODO: enhance this to look at EncounterType node -->
		<xsl:variable name="config" select="isc:evaluate('getCodedEntryConfig','healthcareFacilityTypeCode',../Facility/text())"/>

		<xsl:call-template name="insertCode">
			<xsl:with-param name="name" select="'HealthcareFacilityTypeCode'"/>
			<xsl:with-param name="code">
				<xsl:choose>
					<xsl:when test="$config">
						<xsl:value-of select="$config"/>
					</xsl:when>
					<xsl:when test="$isXACML">385432009^Not Applicable^SNOMED</xsl:when>
					<xsl:otherwise>MHSP^Military Hospital^2.16.840.1.113883.5.11</xsl:otherwise>
				</xsl:choose>
			</xsl:with-param>
		</xsl:call-template>
	</xsl:template>


	<!-- intendedRecipient list for SubmissionSet-->
	<xsl:template mode="intendedRecipient" match="XDSbProcessRequest">
		<!-- By default, no intendedRecipient for submission -->
		<!-- FUTURE: Send more info in the subscription recipient to be able to fill this in -->
	</xsl:template>

	<!-- languageCode for Document-->
	<xsl:template mode="languageCode" match="Document">
		<LanguageCode>en-us</LanguageCode>
	</xsl:template>
	
	<!-- languageCode for Encounter-->
	<xsl:template mode="encounter_languageCode" match="AddUpdateHubEncounterInfo">
		<LanguageCode>en-us</LanguageCode>
	</xsl:template>

	<!-- legalAuthenticator for Document -->
	<xsl:template mode="legalAuthenticator" match="Document">
		<xsl:if test="not($isOnDemand)">
			<!-- By default, no authenticator for stable documents -->
		</xsl:if>
	</xsl:template>

	<!-- legalAuthenticator for Encounter -->
	<xsl:template mode="encounter_legalAuthenticator" match="AddUpdateHubEncounterInfo">
		<xsl:if test="not($isOnDemand)">
			<!-- By default, no authenticator for stable documents -->
		</xsl:if>
	</xsl:template>

	<!-- mimeType for Document -->
	<xsl:template mode="mimeType" match="Document">
		<MimeType>
			<xsl:apply-templates mode="mimeTypeValue" select="."/>
		</MimeType>
	</xsl:template>
	
	<xsl:template mode="mimeTypeValue" match="Document">
		<xsl:choose>
			<xsl:when test="$isXACML">text/xml</xsl:when>
			<xsl:when test="$transformType='PDF'">application/pdf</xsl:when>
			<xsl:when test="$transformType='HTML'">text/html</xsl:when>
			<xsl:when test="$transformType='CUSTOM'">application/octet-stream</xsl:when>
			<xsl:otherwise>text/xml</xsl:otherwise>
		</xsl:choose>
	</xsl:template>
	
	<!-- mimeType for Encounter -->
	<xsl:template mode="encounter_mimeType" match="AddUpdateHubEncounterInfo">
		<MimeType>text/xml</MimeType>
	</xsl:template>
	
	<xsl:template mode="_encounter_mimeTypeValue" match="AddUpdateHubEncounterInfo">
		<xsl:choose>
			<xsl:when test="$isXACML">text/xml</xsl:when>
			<xsl:when test="$transformType='PDF'">application/pdf</xsl:when>
			<xsl:when test="$transformType='HTML'">text/html</xsl:when>
			<xsl:when test="$transformType='CUSTOM'">application/octet-stream</xsl:when>
			<xsl:otherwise>text/xml</xsl:otherwise>
		</xsl:choose>
	</xsl:template>

	<!-- patientId for SubmissionSet -->
	<xsl:template mode="patientId" match="XDSbProcessRequest">
		<PatientId>
			<xsl:value-of select="concat(MPIID/text(),'^^^&amp;',$affinityDomainOID,'&amp;ISO')"/>
		</PatientId>
	</xsl:template>

	<!-- patientId for Document -->
	<xsl:template mode="patientId" match="Document">
		<PatientId>
			<xsl:value-of select="concat(../MPIID/text(),'^^^&amp;',$affinityDomainOID,'&amp;ISO')"/>
		</PatientId>
	</xsl:template>
	
	<!-- patientId for Encounter -->
	<xsl:template mode="encounter_patientId" match="AddUpdateHubEncounterInfo">
		<PatientId>
			<xsl:value-of select="concat(../../../../MPIID/text(),'^^^&amp;',$affinityDomainOID,'&amp;ISO')"/>
		</PatientId>
	</xsl:template>

	<!-- practiceSettingCode for Document -->
	<!-- CUSTOM: default to Military Medicine -->
	<xsl:template mode="practiceSettingCode" match="Document">
		<!-- Default using valid NIST code for connect-a-thon and demo -->
		<!-- RHIO's may override by adding config keys to the registry -->
		<!-- TODO: Enhance this to look at encounter AssignedWard node -->
		<xsl:variable name="config" select="isc:evaluate('getCodedEntryConfig','practiceSettingCode',../Facility/text())"/>
		<xsl:call-template name="insertCode">
			<xsl:with-param name="name" select="'PracticeSettingCode'"/>
			<xsl:with-param name="code">
				<xsl:choose>
					<xsl:when test="$config">
						<xsl:value-of select="$config"/>
					</xsl:when>
					<xsl:when test="$isXACML">385432009^Not Applicable^SNOMED</xsl:when>
					<xsl:otherwise>410001006^Military Medicine^2.16.840.1.113883.6.96</xsl:otherwise>
				</xsl:choose>
			</xsl:with-param>
		</xsl:call-template>
	</xsl:template>

	<!-- practiceSettingCode for Encounter-->
	<!-- CUSTOM: default to Military Medicine -->
	<xsl:template mode="encounter_practiceSettingCode" match="AddUpdateHubEncounterInfo">
		<!-- Default using valid NIST code for connect-a-thon and demo -->
		<!-- RHIO's may override by adding config keys to the registry -->
		<!-- TODO: Enhance this to look at encounter AssignedWard node -->
		
		<!--  changing for encounters test -->
		<!-- <xsl:variable name="config" select="isc:evaluate('getCodedEntryConfig','practiceSettingCode',../Facility/text())"/>  -->
		<xsl:variable name="config" select="isc:evaluate('getCodedEntryConfig','practiceSettingCode',../../Facility/text())"/>
		<xsl:call-template name="insertCode">
			<xsl:with-param name="name" select="'PracticeSettingCode'"/>
			<xsl:with-param name="code">
				<xsl:choose>
					<xsl:when test="$config">
						<xsl:value-of select="$config"/>
					</xsl:when>
					<xsl:when test="$isXACML">385432009^Not Applicable^SNOMED</xsl:when>
					<xsl:otherwise>410001006^Military Medicine^2.16.840.1.113883.6.96</xsl:otherwise>
				</xsl:choose>
			</xsl:with-param>
		</xsl:call-template>
	</xsl:template>


	<!-- CUSTOM: include service times -->
	<xsl:template mode="serviceTimes" match="Document">
		<xsl:param name="docPos" select="0"/>
		<xsl:choose>
			<xsl:when test="$docPos > 0 and $transformOption = 'Z-C62'">
				<xsl:variable name="docDate">
					<xsl:apply-templates mode="getDocProp" select=".">
						<xsl:with-param name="docPos" select="$docPos"/>
						<xsl:with-param name="docProp" select="'Time'"/>
					</xsl:apply-templates>
				</xsl:variable>
				<xsl:if test="string-length($docDate) > 0">
					<ServiceStartTime>
						<xsl:value-of select="translate($docDate, 'TZ:- ', '')"/>
					</ServiceStartTime>
					<ServiceStopTime>
						<xsl:value-of select="translate($docDate, 'TZ:- ', '')"/>
					</ServiceStopTime>
				</xsl:if>
			</xsl:when>
			<!--
			<xsl:when test="$contentScope = 'Enc'">
					<ServiceStartTime>
						<xsl:value-of select="translate(FromTime/text(), 'TZ:- ', '')"/>
					</ServiceStartTime>
					<ServiceStopTime>
						<xsl:value-of select="translate(ToTime/text(), 'TZ:- ', '')"/>
					</ServiceStopTime>
			</xsl:when>
			-->
		</xsl:choose>
	</xsl:template>

	<!-- CUSTOM: include service times -->
	<xsl:template mode="encounter_serviceTimes" match="AddUpdateHubEncounterInfo">
		<xsl:param name="docPos" select="0"/>
		<xsl:choose>
			<xsl:when test="$contentScope = 'Enc'">
				<!-- xsl:if test="AddUpdateHubRequest/Encounters/AddUpdateHubEncounterInfo" -->
					<ServiceStartTime>
						<xsl:value-of select="translate(FromTime/text(), 'TZ:- ', '')"/>
					</ServiceStartTime>
					<ServiceStopTime>
						<xsl:value-of select="translate(ToTime/text(), 'TZ:- ', '')"/>
					</ServiceStopTime>
				<!-- /xsl:if -->
			</xsl:when>
		</xsl:choose>
	</xsl:template>


	<!-- sourceId for SubmissionSet -->
	<xsl:template mode="sourceId" match="XDSbProcessRequest">
		<!-- always use the community OID -->
		<SourceId>
			<xsl:value-of select="$homeCommunityOID"/>
		</SourceId>
	</xsl:template>

	<!-- sourcePatientId for Document -->
	<xsl:template mode="sourcePatientId" match="Document">
		<SourcePatientId>
			<xsl:choose>
				<xsl:when test="$contentScope = 'MPI'">
					<!-- sourcePatientId is requried, so put the MPIID here -->
					<xsl:value-of select="concat(../MPIID/text(),'^^^&amp;',$affinityDomainOID,'&amp;ISO')"/>
				</xsl:when>
				<xsl:otherwise>
					<!-- NOTE: Using the MRN/AA that triggered the push, not the encounter MRN -->
					<xsl:variable name="aaOID" select="isc:evaluate('getOIDForCode',../AssigningAuthority/text(),'AssigningAuthority')"/>
					<xsl:value-of select="concat(../MRN/text(),'^^^&amp;',$aaOID,'&amp;ISO')"/>
				</xsl:otherwise>
			</xsl:choose>
		</SourcePatientId>
	</xsl:template>

	<!-- sourcePatientId for Encounter -->
	<xsl:template mode="encounter_sourcePatientId" match="AddUpdateHubEncounterInfo">
		<SourcePatientId>
			<xsl:choose>
				<xsl:when test="$contentScope = 'MPI'">
					<!-- sourcePatientId is requried, so put the MPIID here -->
					<xsl:value-of select="concat(../../../../MPIID/text(),'^^^&amp;',$affinityDomainOID,'&amp;ISO')"/>
				</xsl:when>
				<xsl:otherwise>
					<!-- NOTE: Using the MRN/AA that triggered the push, not the encounter MRN -->
					<xsl:variable name="aaOID" select="isc:evaluate('getOIDForCode',../../AssigningAuthority/text(),'AssigningAuthority')"/>
					<xsl:value-of select="concat(../../../../MRN/text(),'^^^&amp;',$aaOID,'&amp;ISO')"/>
				</xsl:otherwise>
			</xsl:choose>
		</SourcePatientId>
	</xsl:template>


	<!-- sourcePatientInfo for Document-->
	<xsl:template mode="sourcePatientInfo" match="Document">
		<xsl:choose>
			<xsl:when test="SDA">
				<xsl:variable name="patientRoot" select="SDA/Container/Patient"/>
				<SourcePatientInfo>
					<Value>PID-5|<xsl:value-of select="concat($patientRoot/Name/FamilyName/text(),'^',$patientRoot/Name/GivenName/text())"/>
					</Value>
					<Value>PID-7|<xsl:value-of select="translate($patientRoot/BirthTime/text(),'TZ:- ','')"/>
					</Value>
					<Value>PID-8|<xsl:value-of select="$patientRoot/Gender/Code/text()"/>
					</Value>
					<xsl:variable name="street" select="$patientRoot/Addresses/Address[1]/Street/text()"/>
					<xsl:variable name="street1" select="isc:evaluate('piece',$street,';',1)"/>
					<xsl:variable name="street2" select="isc:evaluate('piece',$street,';',2)"/>
					<xsl:variable name="city" select="$patientRoot/Addresses/Address[1]/City/Code/text()"/>
					<xsl:variable name="state" select="$patientRoot/Addresses/Address[1]/State/Code/text()"/>
					<xsl:variable name="zip" select="$patientRoot/Addresses/Address[1]/Zip/Code/text()"/>
					<xsl:variable name="country" select="$patientRoot/Addresses/Address[1]/Country/Code/text()"/>
					<Value>PID-11|<xsl:value-of select="concat($street1,'^',$street2,'^',$city,'^',$state,'^',$zip,'^',$country)"/>
					</Value>
				</SourcePatientInfo>
			</xsl:when>
			<xsl:when test="AddUpdateHubRequest">
				<SourcePatientInfo>
					<Value>PID-5|<xsl:value-of select="concat(AddUpdateHubRequest/LastName/text(),'^',AddUpdateHubRequest/FirstName/text())"/>
					</Value>
					<Value>PID-7|<xsl:value-of select="translate(AddUpdateHubRequest/DOB/text(),'TZ:- ','')"/>
					</Value>
					<Value>PID-8|<xsl:value-of select="AddUpdateHubRequest/Sex/text()"/>
					</Value>
					<xsl:variable name="street" select="AddUpdateHubRequest/Street/text()"/>
					<xsl:variable name="street1" select="isc:evaluate('piece',$street,';',1)"/>
					<xsl:variable name="street2" select="isc:evaluate('piece',$street,';',2)"/>
					<xsl:variable name="city" select="AddUpdateHubRequest/City/text()"/>
					<xsl:variable name="state" select="AddUpdateHubRequest/State/text()"/>
					<xsl:variable name="zip" select="AddUpdateHubRequest/Zip/text()"/>
					<Value>PID-11|<xsl:value-of select="concat($street1,'^',$street2,'^',$city,'^',$state,'^',$zip)"/>
					</Value>
				</SourcePatientInfo>
			</xsl:when>
		</xsl:choose>

	</xsl:template>

	<!-- sourcePatientInfo for Encounter-->
	<xsl:template mode="encounter_sourcePatientInfo" match="AddUpdateHubEncounterInfo">
		<SourcePatientInfo>
			<Value>PID-5|<xsl:value-of select="concat(../../LastName/text(),'^',../../FirstName/text())"/>
			</Value>
			<Value>PID-7|<xsl:value-of select="translate(DOB/text(),'TZ:- ','')"/>
			</Value>
			<Value>PID-8|<xsl:value-of select="../../Sex/text()"/>
			</Value>
			<xsl:variable name="street" select="../../Street/text()"/>
			<xsl:variable name="street1" select="isc:evaluate('piece',$street,';',1)"/>
			<xsl:variable name="street2" select="isc:evaluate('piece',$street,';',2)"/>
			<xsl:variable name="city" select="../../City/text()"/>
			<xsl:variable name="state" select="../../State/text()"/>
			<xsl:variable name="zip" select="../../Zip/text()"/>
			<Value>PID-11|<xsl:value-of select="concat($street1,'^',$street2,'^',$city,'^',$state,'^',$zip)"/>
			</Value>
		</SourcePatientInfo>
	</xsl:template>


	<!-- submissionTime for SubmissionSet-->
	<xsl:template mode="submissionTime" match="XDSbProcessRequest">
		<SubmissionTime>
			<xsl:value-of select="isc:evaluate('createHL7Timestamp')"/>
		</SubmissionTime>
	</xsl:template>

	<!-- title for SubmissionSet -->
	<xsl:template mode="title" match="XDSbProcessRequest">
		<Title>
			<xsl:value-of select="Subscription/Subject/text()"/>
		</Title>
	</xsl:template>

	<!-- title for Document -->
	<!-- CUSTOM: support C62 doc types -->
	<xsl:template mode="title" match="Document">
		<xsl:param name="docPos" select="0"/>

		<xsl:variable name="scope">
			<xsl:choose>
				<xsl:when test="$isXACML">XACML Privacy Policy</xsl:when>
				<xsl:when test="$docPos > 0">
					<xsl:variable name="docName">
						<xsl:apply-templates mode="getDocProp" select=".">
							<xsl:with-param name="docPos" select="$docPos"/>
							<xsl:with-param name="docProp" select="'Name'"/>
						</xsl:apply-templates>
					</xsl:variable>
					<xsl:variable name="loincName">
						<xsl:apply-templates mode="getDocTitleLOINC" select=".">
							<xsl:with-param name="docPos" select="$docPos"/>
						</xsl:apply-templates>
					</xsl:variable>
					<xsl:choose>
						<xsl:when test="string-length($docName) > 0"><xsl:value-of select="$docName"/>
						</xsl:when>
						<xsl:when test="string-length($loincName) > 0"><xsl:value-of select="$loincName"/>
						</xsl:when>
						<xsl:otherwise>Unstructured Document</xsl:otherwise>
					</xsl:choose>
				</xsl:when>
				<xsl:when test="$contentScope = 'Enc'">Encounter Summary</xsl:when>
				<xsl:when test="$contentScope = 'MRN'">Medical Record Summary</xsl:when>
				<xsl:when test="$contentScope = 'MPI'">Patient Summary</xsl:when>
				<xsl:otherwise>Message Summary</xsl:otherwise>
			</xsl:choose>
		</xsl:variable>

		<xsl:variable name="detail">
			<xsl:choose>
				<xsl:when test="$transformType='PDF'">
					<xsl:value-of select=" (PDF)"/>
				</xsl:when>
				<xsl:when test="$transformType='HTML'">
					<xsl:value-of select=" (HTML)"/>
				</xsl:when>
				<!-- NOTE: overrides of the transform can look at the custom operation to determine a more accurate mimeType -->
				<xsl:when test="$transformType='CUSTOM'">
					<xsl:value-of select=" (Other)"/>
				</xsl:when>
				<xsl:otherwise>
					<!-- CUSTOM: assume CDA -->
					<xsl:value-of select="' (CDA)'"/>
				</xsl:otherwise>
			</xsl:choose>
		</xsl:variable>

		<Title>
			<xsl:value-of select="concat($scope,$detail)"/>
		</Title>
	</xsl:template>

	<!-- title for Encounter -->
	<!-- CUSTOM: support C62 doc types -->
	<xsl:template mode="encounter_title" match="AddUpdateHubEncounterInfo">
		<xsl:param name="docPos" select="0"/>

		<xsl:variable name="scope">
			<xsl:choose>
				<xsl:when test="$contentScope = 'Enc'">Encounter Summary</xsl:when>
				<xsl:when test="$contentScope = 'MRN'">Medical Record Summary</xsl:when>
				<xsl:when test="$contentScope = 'MPI'">Patient Summary</xsl:when>
				<xsl:otherwise>Message Summary</xsl:otherwise>
			</xsl:choose>
		</xsl:variable>

		<xsl:variable name="detail">
			<xsl:choose>
				<xsl:when test="$transformType='PDF'">
					<xsl:value-of select=" (PDF)"/>
				</xsl:when>
				<xsl:when test="$transformType='HTML'">
					<xsl:value-of select=" (HTML)"/>
				</xsl:when>
				<!-- NOTE: overrides of the transform can look at the custom operation to determine a more accurate mimeType -->
				<xsl:when test="$transformType='CUSTOM'">
					<xsl:value-of select=" (Other)"/>
				</xsl:when>
				<xsl:otherwise>
					<!-- CUSTOM: assume CDA -->
					<xsl:value-of select="' (CDA)'"/>
				</xsl:otherwise>
			</xsl:choose>
		</xsl:variable>

		<Title>
			<xsl:value-of select="concat($scope,$detail)"/>
		</Title>
	</xsl:template>


	<!-- typeCode for Document -->
	<!-- CUSTOM: support C62 doc types and use VA values for enc/pat summaries -->
	<xsl:template mode="typeCode" match="Document">
		<xsl:param name="docPos" select="0"/>

		<!-- Default using valid NIST code for connect-a-thon and demo -->
		<!-- RHIO's may override by adding config keys to the registry -->
		<xsl:variable name="config" select="isc:evaluate('getCodedEntryConfig','typeCode',$contentScope,$transformType,$transformOption)"/>
		<xsl:call-template name="insertCode">
			<xsl:with-param name="name" select="'TypeCode'"/>
			<xsl:with-param name="code">
				<xsl:choose>
					<xsl:when test="$config">
						<xsl:value-of select="$config"/>
					</xsl:when>
					<xsl:when test="$isXACML">57017-6^Privacy Policy^LOINC</xsl:when>
					<xsl:when test="$docPos > 0">
						<xsl:apply-templates mode="getDocLOINC" select=".">
							<xsl:with-param name="docPos" select="$docPos"/>
						</xsl:apply-templates>
					</xsl:when>
					<xsl:when test="$contentScope = 'Enc'">
						<xsl:call-template name="toLOINC">
							<xsl:with-param name="type" select="'Encounter'"/>
						</xsl:call-template>
					</xsl:when>
					<xsl:when test="$contentScope = 'MRN'">34117-2^History And Physical Note^LOINC</xsl:when>
					<xsl:when test="$contentScope = 'MPI'">
						<xsl:call-template name="toLOINC">
							<xsl:with-param name="type" select="'Patient'"/>
						</xsl:call-template>
					</xsl:when>
					<xsl:otherwise>34138-8^Targeted History And Physical Note^LOINC</xsl:otherwise>
				</xsl:choose>
			</xsl:with-param>
		</xsl:call-template>
	</xsl:template>

	<!-- typeCode for Document -->
	<!-- CUSTOM: support C62 doc types and use VA values for enc/pat summaries -->
	<xsl:template mode="encounter_typeCode" match="AddUpdateHubEncounterInfo">
		<xsl:param name="docPos" select="0"/>

		<!-- Default using valid NIST code for connect-a-thon and demo -->
		<!-- RHIO's may override by adding config keys to the registry -->
		<xsl:variable name="config" select="isc:evaluate('getCodedEntryConfig','typeCode',$contentScope,$transformType,$transformOption)"/>
		<xsl:call-template name="insertCode">
			<xsl:with-param name="name" select="'TypeCode'"/>
			<xsl:with-param name="code">
				<xsl:choose>
					<xsl:when test="$contentScope = 'Enc'">
						<xsl:call-template name="toLOINC">
							<xsl:with-param name="type" select="'Encounter'"/>
						</xsl:call-template>
					</xsl:when>
					<xsl:otherwise>34138-8^Targeted History And Physical Note^LOINC</xsl:otherwise>
				</xsl:choose>
			</xsl:with-param>
		</xsl:call-template>
	</xsl:template>

	<!-- uniqueId for SubmissionSet -->
	<xsl:template mode="uniqueId" match="XDSbProcessRequest">
		<UniqueId>
			<xsl:value-of select="isc:evaluate('createOID')"/>
		</UniqueId>
	</xsl:template>

	<!-- Document uniqueId -->
	<!-- CUSTOM: use param instead to support multiple C62s -->
	<xsl:template mode="uniqueId" match="Document">
		<xsl:param name="docUID"/>
		<UniqueId>
			<xsl:value-of select="$docUID"/>
		</UniqueId>
	</xsl:template>

	<!-- Encounter uniqueId -->
	<!-- CUSTOM: use param instead to support multiple C62s -->
	<xsl:template mode="encounter_uniqueId" match="AddUpdateHubEncounterInfo">
		<xsl:param name="docUID"/>
		<UniqueId>
			<xsl:value-of select="$docUID"/>
		</UniqueId>
	</xsl:template>
	
	<!-- 

			UTILITY TEMPLATES 
					
-->

	<!-- Generate a simple author element, assuming only one value for institution, role and specialty -->
	<xsl:template name="author">
		<xsl:param name="person"/>
		<xsl:param name="institution"/>
		<xsl:param name="role"/>
		<xsl:param name="specialty"/>

		<!-- Author person is required -->
		<xsl:if test="$person">
			<Author>
				<AuthorPerson>
					<!-- since this is XCN, we should put this in the name piece since some vendors 
   treat the first piece as an id *and* require an AA then
   -->
					<xsl:text>^</xsl:text>   
					<xsl:value-of select="$person"/>
				</AuthorPerson>
				<xsl:if test="$institution">
					<AuthorInstitution>
						<Value>
							<xsl:value-of select="$institution"/>
						</Value>
					</AuthorInstitution>
				</xsl:if>

				<xsl:if test="$role">
					<AuthorRole>
						<Value>
							<xsl:value-of select="$role"/>
						</Value>
					</AuthorRole>
				</xsl:if>

				<xsl:if test="$specialty">
					<AuthorSpecialty>
						<Value>
							<xsl:value-of select="$specialty"/>
						</Value>
					</AuthorSpecialty>
				</xsl:if>

			</Author>
		</xsl:if>
	</xsl:template>

	<!-- Generate author element using the home community -->
	<xsl:template name="communityAuthor">
		<xsl:param name="oid" select="$homeCommunityOID"/>
		<xsl:call-template name="author">
			<xsl:with-param name="person" select="isc:evaluate('getCodeForOID',$oid,'HomeCommunity')"/>
			<xsl:with-param name="institution" select="isc:evaluate('getDescriptionForOID',$oid,'HomeCommunity')"/>
		</xsl:call-template>
	</xsl:template>

	<!-- Generate author element using clinician/entered-by -->
	<xsl:template mode="personAuthor" match="*">
		<xsl:variable name="oid" select="isc:evaluate('getOIDForCode',SDACodingStandard/text(),'AssigningAuthority')"/>
		<xsl:call-template name="author">
			<xsl:with-param name="person" select="Description/text()"/>
			<xsl:with-param name="institution" select="isc:evaluate('getDescriptionForOID',$oid,'AssigningAuthority',SDACodingStandard/text())"/>
			<!-- Care providers can have a role, EnteredBy will not -->
			<xsl:with-param name="role" select="CareProviderType/Description/text()"/>
		</xsl:call-template>
	</xsl:template>

	<!-- Convert a ^ delimited string into coded entry element -->
	<xsl:template name="insertCode">
		<xsl:param name="name"/>
		<xsl:param name="code"/>
		<xsl:element name="{$name}">
			<Code>
				<xsl:value-of select="substring-before($code,'^')"/>
			</Code>
			<Description>
				<xsl:value-of select="substring-before(substring-after($code,'^'),'^')"/>
			</Description>
			<Scheme>
				<xsl:value-of select="substring-after(substring-after($code,'^'),'^')"/>
			</Scheme>
		</xsl:element>
	</xsl:template>

	<!-- CUSTOM: get C62 property -->
	<xsl:template mode="getDocProp" match="Document">
		<xsl:param name="docPos"/>
		<xsl:param name="docProp"/>
		<xsl:variable name="key" select="concat('Document(',$docPos,').',$docProp)"/>
		<xsl:value-of select="AddUpdateHubRequest/AdditionalInfo/AdditionalInfoItem[@AdditionalInfoKey = $key]/text()"/>
	</xsl:template>

	<!-- CUSTOM: get C62 loinc code^title^systemOID -->
	<xsl:template mode="getDocLOINC" match="Document">
		<xsl:param name="docPos"/>
		<xsl:call-template name="toLOINC">
			<xsl:with-param name="type">
				<xsl:apply-templates mode="getDocProp" select=".">
					<xsl:with-param name="docPos" select="$docPos"/>
					<xsl:with-param name="docProp" select="'Type'"/>
				</xsl:apply-templates>
			</xsl:with-param>
		</xsl:call-template>
	</xsl:template>

	<!-- CUSTOM: get C62 loinc title -->
	<xsl:template mode="getDocTitleLOINC" match="Document">
		<xsl:param name="docPos"/>
		<xsl:variable name="loinc">
			<xsl:apply-templates mode="getDocLOINC" select=".">
				<xsl:with-param name="docPos" select="$docPos"/>
			</xsl:apply-templates>
		</xsl:variable>
		<xsl:value-of select="substring-before(substring-after($loinc,'^'),'^')"/>
	</xsl:template>

</xsl:stylesheet>
