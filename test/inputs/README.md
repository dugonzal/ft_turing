# test/inputs

Inputs already in the encoding `res/universal.json` expects, so `test/run.sh` can feed the
universal machine without needing a Python interpreter at test time.

| File                        | What it is                                                                              |
|-----------------------------|-----------------------------------------------------------------------------------------|
| `universal_1_1.txt`         | Machine 1 with the input `1+1`.                                                         |
| `universal_11_11.txt`       | Machine 1 with `11+11`.                                                                 |
| `universal_11_111.txt`      | Machine 1 with `11+111`: sums to five `1`s.                                            |
| `universal_111_111.txt`     | Machine 1 with `111+111`: sums to six `1`s.                                            |
| `universal_sin_regla.txt`   | `universal_11_111.txt` with machine 1's rule for `(seek, 1)` removed, so the simulation gets stuck and the interpreter reports `BLOCKED` instead of inventing a rule. |

All of them are generated:

```
python3 tools/encode_universal.py res/unary_sum.json '11+111' > test/inputs/universal_11_111.txt
```

and the format itself is documented in `README.md`, section 9.
