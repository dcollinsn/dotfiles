DEFINE-DEFAULT copies 1
DEFINE-DEFAULT job_name "Stored PDF"
{
  NAME "M607 store-only Validate-Job"
  OPERATION Validate-Job
  GROUP operation-attributes-tag
  ATTR charset attributes-charset utf-8
  ATTR naturalLanguage attributes-natural-language en
  ATTR uri printer-uri $uri
  ATTR name requesting-user-name $user
  ATTR name job-name "$job_name"
  ATTR mimeMediaType document-format application/pdf
  ATTR boolean ipp-attribute-fidelity true
  ATTR collection job-storage {
    MEMBER keyword job-storage-access public
    MEMBER keyword job-storage-disposition store-only
  }
  GROUP job-attributes-tag
  ATTR integer copies $copies
  ATTR enum print-quality 5
  ATTR resolution printer-resolution 1200dpi
  ATTR integer hp-print-quality-mode 4
  STATUS successful-ok
  EXPECT !job-storage IN-GROUP unsupported-attributes-tag
}
