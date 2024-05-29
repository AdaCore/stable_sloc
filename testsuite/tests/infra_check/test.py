print("This output should never change!")

with open("content.txt") as f:
    print(f.read())
