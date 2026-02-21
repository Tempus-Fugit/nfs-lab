#!/usr/bin/env bash
# generate_shares.sh – Builds /exports/ directory tree on an Alpine NFS server.
# Called with server name argument: generate_shares.sh <nfs1|nfs2>
# Idempotent: re-running creates no duplicates and causes no errors.

set -euo pipefail

SERVER_NAME="${1:?Usage: generate_shares.sh <nfs1|nfs2>}"

mkdir -p /exports
chown devuser:devuser /exports

# ── Share definitions ──────────────────────────────────────────────────────
declare -A SHARES

SHARES["nfs1"]="finance hr engineering legal operations marketing devops security compliance research it-support executive logistics procurement infrastructure analytics training"

SHARES["nfs2"]="operations marketing devops security compliance research it-support executive logistics procurement infrastructure analytics training facilities qa-testing product"

# ── Subdirectory templates per department ──────────────────────────────────
declare -A SUBDIRS

SUBDIRS["finance"]="quarterly-reports annual-budgets audit-trails tax-filings payroll-records expense-reports accounts-payable accounts-receivable invoice-archive financial-models capital-planning board-presentations variance-analysis cost-center-data cash-flow-statements bank-reconciliation"
SUBDIRS["hr"]="employee-records onboarding offboarding performance-reviews benefits-administration job-descriptions recruitment-pipeline compensation-bands training-records org-charts disciplinary-actions leave-management workforce-planning hris-exports policy-documents"
SUBDIRS["engineering"]="architecture-docs api-specifications code-reviews sprint-artifacts release-notes deployment-runbooks infrastructure-diagrams capacity-planning oncall-runbooks postmortems dependency-audits security-reviews test-plans performance-benchmarks prototype-research"
SUBDIRS["legal"]="contracts nda-archive litigation-holds compliance-filings ip-registrations board-minutes shareholder-agreements vendor-agreements employment-law regulatory-correspondence data-privacy audit-findings policy-reviews risk-assessments"
SUBDIRS["operations"]="sop-library incident-reports change-management vendor-contracts sla-documents facilities-requests asset-inventory maintenance-logs operational-metrics escalation-runbooks business-continuity disaster-recovery capacity-reports shift-schedules"
SUBDIRS["marketing"]="campaign-assets brand-guidelines market-research competitive-analysis content-calendar social-media-archive press-releases event-materials product-launches customer-personas demand-gen-reports website-analytics email-templates partner-collateral"
SUBDIRS["devops"]="ci-cd-configs terraform-modules ansible-playbooks kubernetes-manifests monitoring-dashboards alerting-rules runbooks incident-playbooks capacity-plans cost-reports security-scans container-images pipeline-logs environment-configs secrets-rotation"
SUBDIRS["security"]="vulnerability-reports penetration-test-results security-policies incident-response-plans threat-intelligence compliance-audits access-control-reviews firewall-rules certificate-inventory phishing-simulation-results siem-alerts forensic-images risk-register"
SUBDIRS["compliance"]="audit-reports policy-register regulatory-filings gdpr-assessments sox-controls iso27001-evidence hipaa-documentation pci-dss-scans training-completion-records vendor-assessments data-retention-schedules exceptions-log remediation-plans"
SUBDIRS["research"]="white-papers literature-reviews experimental-data lab-notebooks patent-applications conference-submissions grant-proposals research-protocols data-analysis-scripts raw-datasets peer-review-drafts collaboration-agreements equipment-logs"
SUBDIRS["it-support"]="ticket-archives knowledge-base hardware-inventory software-licenses patch-schedules helpdesk-metrics escalation-log user-provisioning asset-lifecycle remote-access-records endpoint-configs network-diagrams training-materials vendor-support-contracts"
SUBDIRS["executive"]="board-meeting-minutes strategic-plans annual-reports investor-presentations m-and-a-documents competitive-intelligence ceo-communications executive-dashboards kpi-reports roadmaps budget-approvals corporate-governance crisis-communications"
SUBDIRS["logistics"]="shipping-manifests carrier-contracts warehouse-layouts inventory-snapshots customs-documents delivery-schedules vendor-purchase-orders returns-processing freight-invoices demand-forecasts route-optimization supply-chain-reports"
SUBDIRS["procurement"]="rfp-documents vendor-evaluations purchase-orders contract-renewals spend-analysis supplier-scorecards catalog-management preferred-vendors price-lists sourcing-strategies approval-workflows compliance-checklists"
SUBDIRS["infrastructure"]="network-topology server-inventory datacenter-layouts cabling-diagrams power-reports cooling-specs hardware-lifecycle firmware-versions backup-schedules dr-configs monitoring-configs capacity-models maintenance-windows"
SUBDIRS["analytics"]="data-models etl-pipelines dashboard-configs report-definitions dataset-catalog data-quality-reports bi-tool-configs warehouse-schema experiment-results ab-test-data ml-model-artifacts feature-engineering audience-segments"
SUBDIRS["training"]="course-catalog learning-paths completion-records certifications-tracking instructor-materials assessment-banks video-library onboarding-modules compliance-training skills-gap-analysis vendor-training-docs lms-exports"
SUBDIRS["facilities"]="floor-plans maintenance-schedules cleaning-contracts hvac-records building-permits safety-inspection-reports security-access-logs renovation-projects equipment-warranties utilities-data lease-agreements visitor-logs"
SUBDIRS["qa-testing"]="test-plans test-cases defect-reports regression-suites automation-scripts performance-test-results user-acceptance-testing release-checklists environment-configs load-test-reports coverage-reports bug-triage tool-configs"
SUBDIRS["product"]="product-roadmaps feature-specs user-stories wireframes ux-research competitive-analysis release-plans changelog-archive customer-feedback prioritization-matrices stakeholder-presentations beta-program-data analytics-reports"

# ── File templates per department ─────────────────────────────────────────
declare -A FILE_TEMPLATES

FILE_TEMPLATES["finance"]="budget_v{N}.xlsx quarterly_report_Q{N}_2024.pdf audit_trail_2024.csv expense_summary_{N}.txt invoice_{N}.pdf payroll_run_{N}.csv ledger_export_{N}.dat tax_filing_2024_{N}.pdf cash_flow_{N}.xlsx variance_report_{N}.txt"
FILE_TEMPLATES["hr"]="employee_{N}_profile.json offer_letter_{N}.pdf performance_review_{N}.docx org_chart_v{N}.svg benefits_enrollment_{N}.csv onboarding_checklist_{N}.txt training_completion_{N}.csv termination_{N}.pdf leave_request_{N}.json policy_v{N}.pdf"
FILE_TEMPLATES["engineering"]="architecture_v{N}.drawio api_spec_v{N}.yaml sprint_{N}_retrospective.md deployment_runbook_{N}.sh postmortem_{N}.md capacity_plan_Q{N}.xlsx security_review_{N}.pdf test_plan_{N}.md dependency_audit_{N}.json performance_bench_{N}.txt"
FILE_TEMPLATES["legal"]="contract_{N}_signed.pdf nda_{N}.docx litigation_hold_{N}.txt ip_filing_{N}.pdf board_minutes_{N}.pdf vendor_agreement_{N}.pdf compliance_filing_{N}.txt risk_assessment_{N}.pdf employment_case_{N}.json data_privacy_impact_{N}.pdf"
FILE_TEMPLATES["operations"]="sop_{N}.pdf incident_report_{N}.txt change_request_{N}.json vendor_contract_{N}.pdf sla_doc_{N}.txt asset_inventory_{N}.csv maintenance_log_{N}.txt ops_metric_{N}.csv escalation_runbook_{N}.sh shift_schedule_{N}.xlsx"
FILE_TEMPLATES["marketing"]="campaign_{N}_brief.pdf brand_asset_{N}.psd market_research_{N}.pdf content_calendar_{N}.xlsx press_release_{N}.docx event_deck_{N}.pptx analytics_report_{N}.csv email_template_{N}.html persona_{N}.pdf competitive_analysis_{N}.pdf"
FILE_TEMPLATES["devops"]="terraform_module_{N}.tf ansible_playbook_{N}.yml k8s_manifest_{N}.yaml ci_config_{N}.yaml monitoring_rule_{N}.json runbook_{N}.md cost_report_{N}.csv security_scan_{N}.json pipeline_log_{N}.txt env_config_{N}.env"
FILE_TEMPLATES["security"]="vuln_report_{N}.pdf pentest_results_{N}.pdf incident_response_{N}.md threat_intel_{N}.txt compliance_audit_{N}.pdf access_review_{N}.csv firewall_rules_{N}.txt cert_inventory_{N}.csv siem_alert_{N}.json forensic_image_{N}.gz"
FILE_TEMPLATES["compliance"]="audit_report_{N}.pdf gdpr_assessment_{N}.pdf sox_control_{N}.xlsx iso27001_evidence_{N}.zip hipaa_doc_{N}.pdf pci_scan_{N}.txt training_completion_{N}.csv vendor_assessment_{N}.pdf exception_{N}.txt remediation_plan_{N}.xlsx"
FILE_TEMPLATES["research"]="whitepaper_{N}.pdf lit_review_{N}.md experimental_data_{N}.csv lab_notebook_{N}.txt patent_app_{N}.pdf conference_paper_{N}.pdf grant_proposal_{N}.docx research_protocol_{N}.pdf dataset_{N}.parquet analysis_script_{N}.py"
FILE_TEMPLATES["it-support"]="ticket_archive_{N}.csv kb_article_{N}.md hardware_inventory_{N}.csv software_license_{N}.txt patch_schedule_{N}.xlsx helpdesk_metric_{N}.csv asset_lifecycle_{N}.json remote_access_log_{N}.txt network_diagram_{N}.drawio vendor_contract_{N}.pdf"
FILE_TEMPLATES["executive"]="board_minutes_{N}.pdf strategic_plan_{N}.pptx annual_report_{N}.pdf investor_deck_{N}.pptx ma_doc_{N}.pdf competitive_intel_{N}.pdf kpi_report_{N}.xlsx roadmap_{N}.pdf budget_approval_{N}.pdf governance_doc_{N}.pdf"
FILE_TEMPLATES["logistics"]="shipping_manifest_{N}.csv carrier_contract_{N}.pdf warehouse_layout_{N}.pdf inventory_snapshot_{N}.csv customs_doc_{N}.pdf delivery_schedule_{N}.xlsx purchase_order_{N}.pdf freight_invoice_{N}.pdf demand_forecast_{N}.xlsx route_optimization_{N}.json"
FILE_TEMPLATES["procurement"]="rfp_{N}.pdf vendor_eval_{N}.pdf purchase_order_{N}.pdf spend_analysis_{N}.xlsx supplier_scorecard_{N}.pdf catalog_update_{N}.csv sourcing_strategy_{N}.pdf approval_workflow_{N}.json price_list_{N}.xlsx compliance_checklist_{N}.txt"
FILE_TEMPLATES["infrastructure"]="network_topology_{N}.drawio server_inventory_{N}.csv datacenter_layout_{N}.pdf firmware_version_{N}.txt backup_schedule_{N}.cron dr_config_{N}.yaml monitoring_config_{N}.json capacity_model_{N}.xlsx maintenance_window_{N}.txt hw_lifecycle_{N}.csv"
FILE_TEMPLATES["analytics"]="data_model_{N}.yaml etl_pipeline_{N}.py dashboard_config_{N}.json report_definition_{N}.sql dataset_catalog_{N}.csv data_quality_report_{N}.pdf warehouse_schema_{N}.sql ml_model_{N}.pkl ab_test_results_{N}.csv feature_engineering_{N}.py"
FILE_TEMPLATES["training"]="course_{N}_syllabus.pdf completion_records_{N}.csv certification_tracker_{N}.xlsx assessment_bank_{N}.json course_{N}_video.mp4 onboarding_module_{N}.pptx compliance_training_{N}.pdf skills_gap_{N}.xlsx lms_export_{N}.csv vendor_training_{N}.pdf"
FILE_TEMPLATES["facilities"]="floor_plan_{N}.pdf maintenance_schedule_{N}.xlsx cleaning_contract_{N}.pdf hvac_record_{N}.txt building_permit_{N}.pdf safety_inspection_{N}.pdf access_log_{N}.csv renovation_project_{N}.pdf equipment_warranty_{N}.pdf utilities_data_{N}.csv"
FILE_TEMPLATES["qa-testing"]="test_plan_{N}.pdf test_case_{N}.xlsx defect_report_{N}.pdf regression_suite_{N}.xml automation_script_{N}.py perf_test_results_{N}.txt uat_report_{N}.pdf release_checklist_{N}.md load_test_{N}.txt coverage_report_{N}.html"
FILE_TEMPLATES["product"]="roadmap_{N}.pdf feature_spec_{N}.md user_story_{N}.txt wireframe_{N}.fig ux_research_{N}.pdf competitive_analysis_{N}.pdf release_plan_{N}.xlsx changelog_{N}.md customer_feedback_{N}.csv stakeholder_deck_{N}.pptx"

# ── Helper: generate files in a directory ────────────────────────────────────
generate_files() {
  local dir="$1"
  local dept="$2"
  local template="${FILE_TEMPLATES[$dept]:-FILE_TEMPLATES[operations]}"
  local file_count=$(( RANDOM % 6 + 15 ))  # 15–20 files
  local template_arr=($template)
  local tlen=${#template_arr[@]}
  local i

  for (( i=1; i<=file_count; i++ )); do
    local tmpl="${template_arr[$(( (i-1) % tlen ))]}"
    local fname="${tmpl//\{N\}/$i}"
    local fpath="${dir}/${fname}"
    if [ ! -f "${fpath}" ]; then
      printf "# %s\n# Generated sample content for %s - file %d\nThis file is part of the %s department data store.\nGenerated: %s\n" \
        "${fname}" "${dept}" "${i}" "${dept}" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "${fpath}"
    fi
  done
}

# ── Helper: generate subdirectories in a share ───────────────────────────────
generate_share() {
  local share_path="$1"
  local dept="$2"
  local subdir_list="${SUBDIRS[$dept]:-}"
  local subdir_arr=($subdir_list)
  local slen=${#subdir_arr[@]}
  local subdir_count=$(( RANDOM % 6 + 15 ))  # 15–20 subdirs
  local i

  mkdir -p "${share_path}"

  for (( i=0; i<subdir_count && i<slen; i++ )); do
    local subdir="${share_path}/${subdir_arr[$i]}"
    mkdir -p "${subdir}"
    generate_files "${subdir}" "${dept}"
  done
}

# ── Main: iterate over shares for this server ─────────────────────────────────
SHARE_LIST="${SHARES[$SERVER_NAME]:-}"
if [ -z "${SHARE_LIST}" ]; then
  echo "ERROR: Unknown server name '${SERVER_NAME}'. Expected nfs1 or nfs2." >&2
  exit 1
fi

echo "==> [${SERVER_NAME}] Generating /exports/ directory tree ..."

for share in $SHARE_LIST; do
  share_path="/exports/${share}"
  echo "  -> Creating share: ${share_path}"
  generate_share "${share_path}" "${share}"
done

# Set ownership of all generated content to devuser
chown -R devuser:devuser /exports/

echo "==> [${SERVER_NAME}] Share generation complete."
