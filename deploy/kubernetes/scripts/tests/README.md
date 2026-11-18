# Helm database URL regression

These tests render the chart and parse its database URLs with PostgreSQL's libpq
parser through psycopg. They do not connect to a database, Docker, or Kubernetes.
They require Helm 3 and Python 3.10+; Python packages below are only needed for
development and do not change the deployed applications.

From the repository root:

```sh
python3 -m venv .venv-chart-tests
.venv-chart-tests/bin/pip install -r deploy/kubernetes/scripts/tests/requirements.txt
helm repo add bitnami https://charts.bitnami.com/bitnami
helm dependency build deploy/kubernetes/charts/greptile
.venv-chart-tests/bin/python -m unittest discover -s deploy/kubernetes/scripts/tests -v
```

Set `HELM` to an explicit Helm executable path if it is not on `PATH`.

The matrix renders 12 credential/database cases with internal and external
Postgres, with and without PgBouncer (48 configurations), plus default settings.
It verifies exact libpq round trips and URI escaping, raw password preservation,
and both migration jobs' direct database URLs. Literal `%2F`, plus, spaces, and
Unicode guard against accidental double decoding and form-style space encoding.
One additional render intentionally uses an invalid HTTP authentication URL and
checks that the failure includes Helm's diagnostic.

Pass raw username, password, and database values to Helm. Do not pre-encode them.
