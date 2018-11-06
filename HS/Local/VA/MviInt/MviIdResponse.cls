Class HS.Local.VA.MviInt.MviIdResponse Extends Ens.Response
{
Property MviIds As %String(MAXLEN=90000);
Storage Default
{
<Data name="MviIdResponseDefaultData">
<Subscript>"MviIdResponse"</Subscript>
<Value name="1">
<Value>MviIds</Value>
</Value>
</Data>
<DefaultData>MviIdResponseDefaultData</DefaultData>
<Type>%Library.CacheStorage</Type>
}

}