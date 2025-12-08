Refs: 
- [Sovereign Public Cloud overview](https://learn.microsoft.com/en-us/industry/sovereign-cloud/sovereign-public-cloud/overview-sovereign-public-cloud)
- [Sovereign Landing Zone (SLZ) overview](https://learn.microsoft.com/en-us/industry/sovereign-cloud/sovereign-public-cloud/sovereign-landing-zone/overview-slz?tabs=hubspoke)
- [Microsoft Cloud for Sovereignty – Baseline Global policies](https://learn.microsoft.com/en-us/azure/governance/policy/samples/mcfs-baseline-global)
- [Microsoft Cloud for Sovereignty – Baseline Confidential policies](https://learn.microsoft.com/en-us/azure/governance/policy/samples/mcfs-baseline-confidential)
- [Filtered Azure Policy initiatives for Sovereign Cloud](https://www.azadvertizer.net/azpolicyinitiativesadvertizer_all.html#%7B%22col_0%22%3A%7B%7D%2C%22col_3%22%3A%7B%22flt%22%3A%22sov%22%7D%7D)

## Azure Sovereign Cloud Concept
Azure Sovereign Cloud lets governments and regulated industries meet strict sovereignty, compliance, and security requirements while benefiting from hyperscale infrastructure.

**Key characteristics**
- **Data residency:** Keeps data within required geopolitical boundaries (e.g., EU Data Boundary) under local regulations.
- **Operational oversight:** Access is tightly controlled, logged, and often performed by screened local personnel; logs are tamper-evident.
- **Customer-managed encryption:** Supports HSM-backed customer keys to maintain ownership of encryption.
- **Deployment models:** Sovereign Public Cloud, Sovereign Private Cloud via Azure Local, and National Partner Clouds for country-specific certifications.
- **Sovereign Landing Zones (SLZ):** Policy-as-code environments enforcing data location, encryption, and architectural guardrails.

## Management Group Structure
Azure Management Groups organize subscriptions above the resource hierarchy for centralized governance.

**Hierarchy**
- Root management group covers the entire tenant; custom groups can nest up to six levels.

**Purpose**
- Logical governance boundaries for policy assignment, compliance, and access—not necessarily billing structures.

**Best practices**
- Maintain a shallow (3–4 level) hierarchy.
- Segment by environment or sensitivity (e.g., Public, Confidential Online, Confidential Corp).
- Reserve tenant root for truly global policies.
- Prefer Azure Policy at management-group level; delegate RBAC at subscription/resource group level.
- Use tags for lateral organization rather than deep nesting.

## Policies
Azure Policy enforces governance rules with automatic inheritance down the hierarchy.

**Enforcement modes**
- **Deny** blocks non-compliant deployments.
- **Audit** records compliance without blocking.
- **Modify/DeployIfNotExists** remediates or auto-deploys required resources.

**Sovereignty scenarios**
- Restrict regions for data residency.
- Enforce customer-managed keys and confidential computing.
- Assign regulatory initiatives (e.g., Microsoft Sovereign Cloud baseline, NIST, ISO 27001).

**Initiatives**
- Bundle related policies to simplify assignment and reporting.

## Azure Built-in Sovereign Cloud Initiatives
- **Global Policy Baseline:** Sovereignty Baseline – Global Policies initiative covering foundational controls like data residency.
- **Confidential Policy Baseline:** Sovereignty Baseline – Confidential Policies initiative enforcing CMK, confidential computing, and advanced safeguards.

**Azure Policy (Regulatory Compliance) visibility**
1. Open **Azure Policy** in the portal.
2. Go to **Definitions** and filter by **Regulatory Compliance**.
3. Locate the two Sovereignty Baseline initiatives.
4. After assignment, use the **Compliance** dashboard (Azure Policy Advisor) to track control status across customer, Microsoft, and shared responsibilities.
