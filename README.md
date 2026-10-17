# first-saas

Service REST **Spring Boot 4.1.1 / Java 25** dont les features Jira validées sont implémentées automatiquement par
**Claude Code** (skills + subagents), puis livrées via **Jenkins** sur **AWS EKS**.

```
Jira (status "Validated")
   │  toutes les 30 min — jenkins/Jenkinsfile.jira-agent
   ▼
scripts/scan-jira.sh ──► claude -p (headless) ──► skill implement-jira-feature
                                                    ├─ subagent jira-analyst   → plan
                                                    ├─ code + subagent test-writer → tests unitaires
                                                    ├─ ./mvnw verify (JaCoCo ≥ 80 %)
                                                    ├─ subagent code-reviewer  → revue
                                                    └─ branche feature/KEY-… + Pull Request
   ▼
Jira : commentaire avec le lien PR + transition "In Review"
   ▼
Revue humaine + merge  ──►  Jenkinsfile : build/tests → image Docker → ECR → Helm EKS staging → approbation → prod
```

Rien n'est mergé ni déployé en production sans validation humaine.

## Lancer en local

Prérequis : JDK 25 (`JAVA_HOME`), Docker.

```powershell
.\mvnw.cmd verify                 # build + tests + gate de couverture
.\mvnw.cmd spring-boot:run        # http://localhost:8080/api/v1/projects
.\mvnw.cmd package; docker build -t first-saas .
```

## Ce qu'il faut regarder pour apprendre Claude Code

| Fichier | Concept Claude Code |
|---|---|
| [CLAUDE.md](CLAUDE.md) | Mémoire projet : conventions, commandes, pièges Spring Boot 4. Chargée à chaque session |
| [.claude/skills/implement-jira-feature/SKILL.md](.claude/skills/implement-jira-feature/SKILL.md) | **Skill** = workflow réutilisable, invocable par `/implement-jira-feature SAAS-42` ou automatiquement quand la demande correspond à sa `description` |
| [.claude/skills/spring-unit-tests/SKILL.md](.claude/skills/spring-unit-tests/SKILL.md) | Skill de « connaissance » : conventions de test, préchargée dans le subagent test-writer |
| [.claude/agents/](.claude/agents/) | **Subagents** : contexte isolé, outils restreints (`tools:`), un rôle chacun (analyste, testeur, reviewer) |
| [.claude/settings.json](.claude/settings.json) | **Permissions** : ce que l'agent peut faire sans demander (`allow`) et ce qui lui est interdit (`deny` : push sur main, kubectl, aws…) |
| [scripts/scan-jira.sh](scripts/scan-jira.sh) | **Mode headless** : `claude -p … --output-format json` piloté par un script |

Parcours conseillé :

1. Ouvre une session `claude` dans ce dossier et demande « ajoute un endpoint DELETE pour les projets » : observe
   comment `CLAUDE.md` et la skill `spring-unit-tests` sont utilisés.
2. Lance la skill à la main sur un vrai ticket : `/implement-jira-feature SAAS-1` (variables Jira exportées, voir ci-dessous).
3. Modifie un subagent (ex. rends `code-reviewer` plus strict) et compare les résultats.
4. Seulement ensuite, active le job Jenkins.

Pistes suivantes : des **hooks** (`PostToolUse` qui lance le formatage après chaque édition), le serveur **MCP
Atlassian** à la place de `scripts/jira.sh` en usage interactif, `/code-review` sur les PR générées.

## Workflow Jira

Statuts attendus (modifiables via variables d'env) : `Validated` → `In Review`.
Le job pose des labels pour être idempotent :

| Label | Sens |
|---|---|
| `claude-in-progress` | ticket en cours de traitement |
| `claude-done` | PR ouverte |
| `claude-failed` | échec ou questions postées en commentaire — retirer le label pour relancer |

Un ticket est bien traité par l'agent s'il contient des **critères d'acceptation** clairs. Si les critères sont
dans un champ personnalisé, renseigne `JIRA_AC_FIELD` (ex. `customfield_10035`).

Test du client Jira en local (Git Bash) :

```bash
export JIRA_BASE_URL=https://your-company.atlassian.net JIRA_USER=you@example.com JIRA_API_TOKEN=...
scripts/jira.sh get SAAS-1
```

## Jenkins

**Job 1 — application** : *Multibranch Pipeline* sur ce repo, `Jenkinsfile`.
**Job 2 — agent Jira** : *Pipeline* (branche `main`), script path `jenkins/Jenkinsfile.jira-agent`.

Plugins : Pipeline, Docker Pipeline, Git, JUnit, Coverage, CloudBees AWS Credentials.
Agent Jenkins avec le label `docker` : Docker, AWS CLI v2, kubectl, Helm 3.

Credentials à créer :

| ID | Type | Usage |
|---|---|---|
| `aws-jenkins` | AWS Credentials | push ECR + déploiement EKS |
| `anthropic-api-key` | Secret text | Claude Code |
| `jira-api` | Username/password | email Jira + API token |
| `github-bot` | Secret text | PAT fine-grained (contents + pull requests en écriture, ce repo uniquement) |

Le job 2 pousse en HTTPS via `gh auth setup-git` : configure le repo dans Jenkins avec une URL `https://`.

À adapter (`TODO` dans les fichiers) : `AWS_ACCOUNT`, `JIRA_BASE_URL`, `JIRA_PROJECT`, host de l'ingress.

## Mise en place AWS

```bash
eksctl create cluster -f infra/eks/cluster.yaml
aws ecr create-repository --repository-name first-saas --region eu-west-3 \
  --image-scanning-configuration scanOnPush=true
```

Puis :

- donner à l'utilisateur/role IAM de Jenkins l'accès au cluster
  (`aws eks create-access-entry` + `associate-access-policy` avec `AmazonEKSClusterAdminPolicy`, ou plus restreint par namespace) ;
- pour exposer l'API : installer l'**AWS Load Balancer Controller**, créer un certificat ACM, puis activer
  `ingress.enabled` dans `deploy/helm/first-saas/values-prod.yaml`.

## Structure

```
src/                              application Spring Boot (feature "project" d'exemple)
.claude/                          skills, subagents, permissions Claude Code
scripts/                          client Jira + scanner headless
Jenkinsfile                       CI/CD application
jenkins/                          job agent Jira + image Docker de l'agent
deploy/helm/first-saas/           chart Helm (staging / prod)
infra/eks/                        cluster EKS (eksctl)
```
