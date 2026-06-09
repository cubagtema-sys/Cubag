from werkzeug.security import check_password_hash

hash = 'scrypt:32768:8:1$It64zGeQ1yyI1XML$ac7e34c3d0e5cee1e40e1d74951df232676eb05c86305e138a7aebc06cbcde558d1be3c94af896d78bb5c8c2d96b82508cd01993a50028fcb66bbc4fc22f1bf3'
password = 'admin_password_123'

if check_password_hash(hash, password):
    print("Match!")
else:
    print("No match.")
