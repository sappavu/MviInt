Class HS.Local.VA.MviInt.MviIdRequest Extends Ens.Request
{
Property Id As %String;
Property FacilityCode As %String;

Storage Default
{
<Data name="MviIdRequestDefaultData">
<Subscript>"MviIdRequest"</Subscript>
<Value name="1">
<Value>Id</Value>
</Value>
<Value name="2">
<Value>FacilityCode</Value>
</Value>
</Data>
<DefaultData>MviIdRequestDefaultData</DefaultData>
<Type>%Library.CacheStorage</Type>
}

}