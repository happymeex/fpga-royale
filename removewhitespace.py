x=open("instructions.txt")
lines=x.readlines();
x.close();
with open('cleaninstructions.txt', 'w') as f:
    for line in lines:
        line =line.strip()
        if (line.find("//")!=-1):
            line=line[:line.find("//")]
        if (line!=""):

            delims=[","]
            for delim in delims:
                line=" ".join(line.split(delim))
            line= " ".join([i for i in line.split() if i!=""])

            f.write(line+"\n");

