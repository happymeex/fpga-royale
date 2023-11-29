x=open("cleaninstructions.txt")
def binary(x,length):
    ret=str(bin(int(x)))[2:]
    if (len(ret)<length):
        for i in range(length-len(ret)):
            ret="0"+ret;
    elif (len(ret)>length):
        raise Exception("number too large",ret,len(ret));
    return ret;
def tohex(x,length):
    ret=str(hex(int(x, 2)))[2:]
    if (len(ret)<length):
        for i in range(length-len(ret)):
            ret="0"+ret;
    return ret;
registers={
    "x0": "00000",
    "x1": "00001",
    "x2": "00010",
    "x3": "00011",
    "x4": "00100",
    "x5": "00101",
    "x6": "00110",
    "x7": "00111",
    "x8": "01000",
    "x9": "01001",
    "x10": "01010",
    "x11": "01011",
}
sprites={
    "s0": "000000",
    "s1": "000001",
    "s2": "000010",
    "s3": "000011",
    "s4": "000100",
    "s5": "000101",
    "s6": "000110",
    "s7": "000111",
    "s8": "001000",
    "s9": "001001",
    "s10": "001010",
    "s11": "001011",
}
for i in range(64):
    sprites["s"+str(i)]=binary(i,6);
instructions={
    "splw":"0000011",
    "lw":"0000011",
    "spsw":"0100011",
    "sw":"0100011",
    "li":"0110111",
    "spli":"0110111",
    "splreg":"0000001",
    "lisp":"0111111",
    "dist":"1111111",
    "wait":"1111111",
    "spaddi":"0010011",
    "spsubi":"0010011",
    "addi":"0010011",
    "subi":"0010011",
    "slli":"0010011",
    "multi":"0010011",
    "srli":"0010011",
    "add":"0110011",
    "sub":"0110011",
    "sll":"0110011",
    "mult":"0110011",
    "srl":"0110011",
    "spsub":"0110011",
    "spadd":"0110011",
    "subsp":"0110011",
    "addsp":"0110011",
    "sub":"0110011",
    "jmp":"1100001",
    "jalr":"1100111",
    "jal":"1101111",
    "blt":"1100011",
    "beq":"1100011",
    "bne":"1100011",
    "bge":"1100011",
    "spbeq":"1100011",
    "attack":"0111011",
}
immediateinstr={
    "addi":"000",
    "subi":"001",
    "slli":"010",
    "multi":"011",
    "srli":"101",
    "spsubi":"001",
    "spaddi":"000",
}
regreginstr={
    "add":"0000000",
    "sub":"0000001",
    "sll":"0000010",
    "mult":"0000011",
    "srl":"0000100",
}
branchinstr={
    "beq":"000",
    "bne":"001",
    "bge":"101",
    "blt":"100",
    "spbeq":"000",
    "spbne":"001",
    "spbge":"101",
    "spblt":"100"
}
count=0;
loops={}
INSTRUCTION_SIZE=9
lines1=x.readlines();
lines=[]
for line in lines1:
        words=line.rstrip("\n").split(" ");
        words=[word.strip(",") for word in words]
      #  if (words[-1][:4]=="LOOP"):
       #     loops[words[-1]]=count
        if (len(words)==1):
            loops[words[0]]=count;
        else:
            lines.append(" ".join(words))
            count+=1
print(loops)
print("count:",count)
with open('data/instructions.mem', 'w') as f:
    for line in lines:
        words=line.rstrip("\n").split(" ");
        words=[word.strip(",") for word in words]
        words[0]=words[0].lower();
     #   if (words[-1][:4]=="LOOP"):
      #      words.pop()
       # if(True):
        if (words[0]=="jmp"):
            #words[1]=words[1][1:] #first char is !
            if (words[1] not in loops):
                raise Exception("loop not found: ",words[1])
            f.write(tohex(binary(loops[words[1]],25)+"1100001",INSTRUCTION_SIZE)+"\n")
        elif (words[0]=="wait"):
            f.write(tohex("0000"+binary(words[1],25)+"1111111",INSTRUCTION_SIZE)+"\n")
        elif (words[0]=="jal"):
            loop=words[2]
            if (loop not in loops):
                raise Exception("loop not found: ",words[1])
            if words[1] not in registers:
                raise Exception("syntax error register not present: ",words[1])
            f.write(tohex("0000"+binary(loops[loop],20)+registers[words[1]]+instructions[words[0]],INSTRUCTION_SIZE)+"\n")
        # elif (words[0]=="splw" or words[0]=="spsw"):
        #     rs1=words[2][words[2].find("(")+1:-1]
        #     offset=words[2][:words[2].find("(")]
        #     if words[1] not in registers or rs1 not in registers:
        #         raise Exception("syntax error register not present: ",rs1)
        #     f.write(tohex(binary(words[3],3)+"1"+binary(offset,12)+registers[rs1]+"01"+registers[words[1]]+instructions[words[0]],INSTRUCTION_SIZE)+"\n")
        elif (words[0]=="lw" or words[0]=="sw" or words[0]=="jalr"):
            rs1=words[2][words[2].find("(")+1:-1]
            offset=words[2][:words[2].find("(")]
            if words[1] not in registers or rs1 not in registers:
                raise Exception("syntax error register not present: ",rs1)
            f.write(tohex(binary(offset,12)+registers[rs1]+"010"+registers[words[1]]+instructions[words[0]],INSTRUCTION_SIZE)+"\n")
        elif (words[0]=="li"):
            if words[1] not in registers:
                raise Exception("syntax error register not present")
            f.write(tohex(binary(words[2],20)+registers[words[1]]+instructions[words[0]],INSTRUCTION_SIZE)+"\n")
        elif (words[0]=="splreg"):
            if words[1] not in registers or words[2] not in registers:
                raise Exception("syntax error register not present")
            f.write(tohex(binary(words[3],3)+"1"+binary("0",15)+registers[words[1]]+registers[words[2]]+instructions[words[0]],INSTRUCTION_SIZE)+"\n")
        elif (words[0]=="spli"):
            if words[1] not in registers:
                raise Exception("syntax error register not present")
            f.write(tohex(binary(words[3],3)+"1"+binary(words[2],20)+registers[words[1]]+instructions[words[0]],INSTRUCTION_SIZE)+"\n")
        elif (words[0]=="lisp"):
            if words[1] not in registers or words[2] not in registers:
                raise Exception("syntax error register/sprite not present")
            f.write(tohex(binary(words[3],3)+"1"+binary("0",12)+registers[words[1]]+"000"+registers[words[2]] + instructions[words[0]],INSTRUCTION_SIZE)+"\n")
        elif (words[0]=="spaddi" or words[0]=="spsubi"):
            if words[1] not in registers or words[2] not in registers:
                raise Exception("syntax error register/sprite not present")
            f.write(tohex(binary(words[4],3)+"1"+binary(words[3],12)+registers[words[2]]+immediateinstr[words[0]]+registers[words[1]] + instructions[words[0]],INSTRUCTION_SIZE)+"\n")
        elif (words[0]=="addi" or words[0]=="subi" or words[0]=="slli" or words[0]=="multi" or
              words[0]=="srli"):
            if words[1] not in registers or words[2] not in registers:
                raise Exception("syntax error register not present")
            f.write(tohex(binary(words[3],12)+registers[words[2]]+immediateinstr[words[0]]+registers[words[1]] + instructions[words[0]],INSTRUCTION_SIZE)+"\n")
        elif (words[0]=="spadd"):
            if words[1] not in registers or words[2] not in registers:
                raise Exception("syntax error register/sprite not present")
            f.write(tohex(binary(words[3],3)+"1"+binary("0",12)+registers[words[2]]+"000"+registers[words[1]] + instructions[words[0]],INSTRUCTION_SIZE)+"\n")
        elif (words[0]=="addsp"):#destionation is register
            if words[1] not in registers or words[2] not in registers:
                raise Exception("syntax error register/sprite not present")
            f.write(tohex(binary(words[3],3)+"1"+"000000100000"+registers[words[1]]+"000"+registers[words[2]] + instructions[words[0]],INSTRUCTION_SIZE)+"\n")
        elif (words[0]=="subsp"): #destination is register
            if words[1] not in registers or words[2] not in registers:
                raise Exception("syntax error register/sprite not present")
            f.write(tohex(binary(words[3],3)+"1"+"010000100000"+registers[words[1]]+"000"+registers[words[2]] + instructions[words[0]],INSTRUCTION_SIZE)+"\n")
        elif (words[0]=="spsub"):
            if words[1] not in registers or words[2] not in registers:
                raise Exception("syntax error register/sprite not present")
            f.write(tohex(binary(words[3],3)+"1"+"010000000000"+registers[words[2]]+"000"+registers[words[1]] + instructions[words[0]],INSTRUCTION_SIZE)+"\n")
        elif (words[0]=="add" or words[0]=="sub" or words[0]=="sll" or words[0]=="mult" or words[0]=="srl"):
            if words[1] not in registers or words[2] not in registers or words[3] not in registers:
                raise Exception("syntax error register not present")
            f.write(tohex(regreginstr[words[0]]+registers[words[3]]+registers[words[2]]+"000"+registers[words[1]] + instructions[words[0]],INSTRUCTION_SIZE)+"\n")
        # elif (words[0]=="sub"):
        #     if words[1] not in registers or words[2] not in registers or words[3] not in registers:
        #         raise Exception("syntax error register not present")
        #     f.write(tohex("0100000"+registers[words[3]]+registers[words[2]]+"000"+registers[words[1]] + instructions[words[0]],INSTRUCTION_SIZE)+"\n")
        elif (words[0]=="beq" or words[0]=="bne" or words[0]=="bge" or words[0]=="blt"):
            #words[3]=words[3][1:] #first char is !
            if (words[3] not in loops):
                raise Exception("loop not found: ",words[3])
            loop=binary(loops[words[3]],12)
            if words[1] not in registers or words[2] not in registers:
                raise Exception("syntax error register not present")
            f.write(tohex("0000"+loop[0:7]+registers[words[1]]+registers[words[2]]+branchinstr[words[0]]+loop[7:12] + instructions[words[0]],INSTRUCTION_SIZE)+"\n")
        elif (words[0]=="spbeq" or words[0]=="spbne" or words[0]=="spbge" or words[0]=="spblt"): #not done yet
            words[3]=words[3][1:] #first char is !
            if (words[3] not in loops):
                raise Exception("loop not found: ",words[3])
            loop=binary(loops[words[3]],12)
            if words[1] not in registers or words[2] not in registers:
                raise Exception("syntax error register not present")
            f.write(tohex("0001"+loop[0:7]+registers[words[1]]+registers[words[2]]+branchinstr[words[0]]+loop[7:12] + instructions[words[0]],INSTRUCTION_SIZE)+"\n")
        elif (words[0]=="attack"):
            if words[1] not in registers or words[2] not in registers:
                raise Exception("syntax error register/sprite not present")
            f.write(tohex("0001"+binary(words[3],3)+binary(words[4],3)+binary("0",6)+registers[words[2]]+"000"+registers[words[1]] + instructions[words[0]],INSTRUCTION_SIZE)+"\n")
        elif (words[0]=='dist'):
            if (words[1] not in registers or words[2] not in registers or words[3] not in registers):
                raise Exception("syntax error register/sprite not present")
            f.write(tohex(binary(words[4],3)+"1"+binary(words[5],3)+binary("0",4)+registers[words[1]]+registers[words[2]] +"0"+ registers[words[3]]+instructions[words[0]],INSTRUCTION_SIZE)+"\n")

