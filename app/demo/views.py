import os
import sys
from django.http import JsonResponse


def index(request):
    # Test scipy and scikit-sparse
    try:
        import numpy as np
        from scipy import sparse

        # Test scikit-sparse CHOLMOD
        from sksparse.cholmod import cholesky

        # Create a symmetric positive definite matrix
        A = sparse.csc_matrix([[4, 1, 0], [1, 3, 1], [0, 1, 2]], dtype=float)
        b = np.array([1, 2, 3], dtype=float)

        # Solve using CHOLMOD
        factor = cholesky(A)
        x = factor(b)
        scipy_status = f"scikit-sparse CHOLMOD OK, solution: {x.tolist()}"
    except Exception as e:
        scipy_status = f"scipy/sksparse error: {e}"

    return JsonResponse(
        {
            "status": "ok",
            "message": "Django running in systemd portable service!",
            "python_version": sys.version,
            "pid": os.getpid(),
            "cwd": os.getcwd(),
            "scipy": scipy_status,
        }
    )
