#!/usr/bin/env bash
# run_tests.sh — Roda pytest com cobertura e compara com a meta do sprint.
#
# Uso:
#   bash .agents/skills/generate-tests/scripts/run_tests.sh [sprint_number]
#
# Exemplos:
#   bash .agents/skills/generate-tests/scripts/run_tests.sh 3   → meta 60%
#   bash .agents/skills/generate-tests/scripts/run_tests.sh      → sem meta

set -euo pipefail

SPRINT="${1:-0}"

# Metas de cobertura por sprint (definidas em implementation.md)
declare -A GOALS=(
    [1]=0
    [2]=50
    [3]=60
    [4]=70
    [5]=75
    [6]=80
)

GOAL="${GOALS[$SPRINT]:-0}"

echo "═══════════════════════════════════════════════════"
echo "  OpenLift — Test Runner (Sprint $SPRINT, Meta: ${GOAL}%)"
echo "═══════════════════════════════════════════════════"
echo ""

cd api

# Cria diretório de relatórios
mkdir -p reports

# Roda os testes com cobertura
pytest \
    --tb=short \
    -q \
    --cov=app \
    --cov-report=term-missing \
    --cov-report=xml:reports/coverage.xml \
    --junitxml=reports/junit.xml \
    "$@"

EXIT_CODE=$?

echo ""
echo "───────────────────────────────────────────────────"

if [ "$GOAL" -gt 0 ]; then
    # Extrai a porcentagem total de cobertura do XML
    COVERAGE=$(python3 -c "
import xml.etree.ElementTree as ET
tree = ET.parse('reports/coverage.xml')
rate = float(tree.getroot().attrib['line-rate']) * 100
print(f'{rate:.1f}')
")

    echo "  Cobertura atual: ${COVERAGE}%"
    echo "  Meta Sprint $SPRINT: ${GOAL}%"

    if (( $(echo "$COVERAGE < $GOAL" | bc -l) )); then
        echo "  ⚠ ABAIXO DA META"
        if [ "$SPRINT" -ge 4 ]; then
            echo "  ✖ CI BLOQUEANTE — este PR não pode ser mergeado."
            exit 1
        else
            echo "  ℹ Informativo — CI não bloqueia neste sprint."
        fi
    else
        echo "  ✔ Meta atingida!"
    fi
fi

echo "═══════════════════════════════════════════════════"
exit $EXIT_CODE
