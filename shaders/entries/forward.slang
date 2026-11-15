import lib.common;
import lib.vertex;
import lib.material;
import passes.forward;

[shader("vertex")]
FragmentInput VSMain(
    uint drawID: SV_DrawIndex,
    uint instanceID: SV_InstanceID, 
    uint vertexID: SV_VertexID
) {
    return ForwardVertex(drawID, instanceID, vertexID);
}

[shader("fragment")]
float4 FSMain<M: Material>(FragmentInput input): SV_Target {
    return ForwardFragment<M>(input);
}
