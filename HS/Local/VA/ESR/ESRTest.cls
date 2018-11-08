Class HS.Local.VA.ESR.ESRTest Extends %RegisteredObject
{
ClassMethod MainESR()
{
    SET Addr="One Memorial Drive"
    SET City="Cambridge"
    SET State="MA"
    SET Zip="02142"

    SET Mail = $LISTBUILD(Addr,City,State,Zip)
}
}