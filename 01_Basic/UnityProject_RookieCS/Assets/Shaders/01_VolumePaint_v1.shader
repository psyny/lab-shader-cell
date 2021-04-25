Shader "Cell/VolumePaint"
{
    Properties
    {
        // _MainTex ("Texture", 2D) = "white" {}
        _ObjectColor ("Object Color", Color) = (1,1,1,1)
        _AmbientLight ("Ambient Light", Color) = (0.20,0.30,0.40,1)
        
        _DarknessThreshold ("Darkness Threshold", Range(0,1)) = 0.5
        _DarknessAmbientValue ("Darkness Ambient Value", Range(0,1)) = 0.2
        _ShadowThreshold ("Shadow Threshold", Range(0,1)) = 0.15
        _ShadowLightValue ("Shadow Light Value", Range(0,1)) = 0.15
        _LightMinValue ("Light Min Value", Range(0,1)) = 0.5
        
        _Specular ("Specular", Range(1,200)) = 3
        _SpecularAlpha ("Specular Alpha", Range(0,1)) = 0
        _CellSpecular ("Cell Specular", Range(1,200)) = 20.0
        _CellSpecularAlpha ("Cell Specular Alpha", Range(0,1)) = 0.1
        
        _DarkenViewTangent ("Darken View Tangent", Range(0,1)) = 0.1
        
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        
        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"
            #include "UnityLightingCommon.cginc"
            #include "AutoLight.cginc"

            // Comes from Mesh and into Vertex Shader
            struct VertexInput
            {
                float4 vertex : POSITION;
                float4 normal : NORMAL;
                float4 colors : COLOR;
                float4 tangent : TANGENT;
                float2 uv0 : TEXCOORD0;
                float2 uv1 : TEXCOORD1;                
            };
            
            fixed4 _ObjectColor;
            fixed4 _AmbientLight;

            float _DarknessThreshold;
            float _DarknessAmbientValue;
            float _ShadowThreshold;
            float _ShadowLightValue;
            float _LightMinValue;
            
            float _Specular;
            float _SpecularAlpha;
            float _CellSpecular;
            float _CellSpecularAlpha;
            
            float _DarkenViewTangent;
            
            // Functions
            // Remap
            float remap(float iMin, float iMax, float oMin, float oMax, float inputValue) {
              float relativeInput = ( inputValue - iMin ) / ( iMax - iMin );
              float oInc = oMax - oMin;
              float oVal = oMin + (oInc * relativeInput);
              
              if (oVal > oMax)
                oVal = oMax;
              else if(oVal < oMin)
                oVal = oMin;
              
              return oVal;
            }

            // Comes out of Vertex Shader 
            struct VertexOutput
            {
                float4 vertex : SV_POSITION;
                float4 normal : NORMAL;
                float3 worldPos : TEXCOORD2;
            };
            


            VertexOutput vert (VertexInput v)
            {
                VertexOutput o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.normal = v.normal;
                o.worldPos = mul( unity_ObjectToWorld, v.vertex );
                return o;
            }

            fixed4 frag (VertexOutput o) : SV_Target
            {
                float3 normal = float3(o.normal.xyz);
                float3 normalizedNormal = normalize(normal);
                float3 worldNormal =  mul( unity_ObjectToWorld, normal );
                worldNormal = normalize( worldNormal );
            
                // Cell Shading Diffuse Variables
                float CS_shadow_input_lowerbound = 0;
                float CS_shadow_input_upperbound = _ShadowThreshold;
                float CS_shadow_output_lowerbound = 0;
                float CS_shadow_output_upperbound = _ShadowLightValue;
                
                float CS_penumbra_input_lowerbound = CS_shadow_input_upperbound;
                float CS_penumbra_input_upperbound = CS_penumbra_input_lowerbound + 0.01;
                float CS_penumbra_output_lowerbound = CS_shadow_output_upperbound;
                float CS_penumbra_output_upperbound = _LightMinValue;
                
                float CS_light_input_lowerbound = CS_penumbra_input_upperbound;
                float CS_light_input_upperbound = 1.0;
                float CS_light_output_lowerbound = CS_penumbra_output_upperbound;
                float CS_light_output_upperbound = 1.0;
                
                // Cell Shading Specular Variables
                float CS_Spec_shadow_input_lowerbound = 0;
                float CS_Spec_shadow_input_upperbound = 0.1;
                float CS_Spec_shadow_output_lowerbound = 0;
                float CS_Spec_shadow_output_upperbound = 0.1;
                
                float CS_Spec_penumbra_input_lowerbound = CS_Spec_shadow_input_upperbound;
                float CS_Spec_penumbra_input_upperbound = CS_Spec_penumbra_input_lowerbound + 0.05;
                float CS_Spec_penumbra_output_lowerbound = CS_Spec_shadow_output_upperbound;
                float CS_Spec_penumbra_output_upperbound = 0.8;
                
                float CS_Spec_light_input_lowerbound = CS_Spec_penumbra_input_upperbound;
                float CS_Spec_light_input_upperbound = 1.0;
                float CS_Spec_light_output_lowerbound = CS_Spec_penumbra_output_upperbound;
                float CS_Spec_light_output_upperbound = 1.0;
                
                // Cell Shading ambient falloff Variables (AFO)
                float CS_AFO_dark_input_limit = -_DarknessThreshold;
                float CS_AFO_dark_output_value = _DarknessAmbientValue;

                float CS_AFO_penumbra_input_lowerbound = CS_AFO_dark_input_limit;
                float CS_AFO_penumbra_input_upperbound = CS_AFO_penumbra_input_lowerbound + 0.02;
                float CS_AFO_penumbra_output_lowerbound = CS_AFO_dark_output_value;                
                float CS_AFO_penumbra_output_upperbound = 1.0;
                
                
                // ---------------------------------------------
                
                // ---------------- Diffuse

                // Light Position Data
                float3 lightPos = _WorldSpaceLightPos0.xyz;
                float3 localLightDir =  mul( unity_WorldToObject, lightPos);
                localLightDir = normalize(localLightDir);
                
                // Diffuse Light
                float3 directLightColor = float3(_LightColor0.rgb);
                float rawDiffuseFalloff = dot(localLightDir, normalizedNormal);
                float diffuseFalloff = max(0, rawDiffuseFalloff);                
                                
                // Cell Shading Diffuse Falloff
                if (diffuseFalloff < CS_shadow_input_upperbound) {
                  diffuseFalloff = remap(CS_shadow_input_lowerbound, CS_shadow_input_upperbound, CS_shadow_output_lowerbound, CS_shadow_output_upperbound, diffuseFalloff);
                } 
                else if (diffuseFalloff < CS_penumbra_input_upperbound) {
                  diffuseFalloff = remap(CS_penumbra_input_lowerbound, CS_penumbra_input_upperbound, CS_penumbra_output_lowerbound, CS_penumbra_output_upperbound, diffuseFalloff);
                }
                else {
                  diffuseFalloff = remap(CS_light_input_lowerbound, CS_light_input_upperbound, CS_light_output_lowerbound, CS_light_output_upperbound, diffuseFalloff);
                }

                float3 directDiffuse = directLightColor * diffuseFalloff;
                
                // ---------------- Specular Base
                float3 camPos = _WorldSpaceCameraPos;
                float3 fragToCam = camPos - o.worldPos;
                float3 viewDir = normalize( fragToCam );
                float3 H = normalize(viewDir + lightPos);
                
                float specularFalloff = max( 0, dot( worldNormal , H) );
                
                // ---------------- Phong Specular
                float phongSpecularFalloff = pow(specularFalloff, _Specular);
                float3 phongDirectSpecular =  directLightColor * phongSpecularFalloff * _SpecularAlpha;
                
                // ---------------- Cell Specular

                float cellSpecularFalloff = pow(specularFalloff, _CellSpecular);
                
                // Cell Shading Specular Falloff
                if (cellSpecularFalloff < CS_Spec_shadow_input_upperbound) {
                  cellSpecularFalloff = remap(CS_Spec_shadow_input_lowerbound, CS_Spec_shadow_input_upperbound, CS_Spec_shadow_output_lowerbound, CS_Spec_shadow_output_upperbound, cellSpecularFalloff);
                } 
                else if (cellSpecularFalloff < CS_Spec_penumbra_input_upperbound) {
                  cellSpecularFalloff = remap(CS_Spec_penumbra_input_lowerbound, CS_Spec_penumbra_input_upperbound, CS_Spec_penumbra_output_lowerbound, CS_Spec_penumbra_output_upperbound, cellSpecularFalloff);
                }
                else {
                  cellSpecularFalloff = remap(CS_Spec_light_input_lowerbound, CS_Spec_light_input_upperbound, CS_Spec_light_output_lowerbound, CS_Spec_light_output_upperbound, cellSpecularFalloff);
                }
                
                float3 cellDirectSpecular =  directLightColor * cellSpecularFalloff * _CellSpecularAlpha;
                
                // ---------------- Normal to camera falloff Direction
                float cameraFalloff = 1.0;
                if (_DarkenViewTangent > 0) {
                  cameraFalloff = max( 0, dot( viewDir , worldNormal) );
                  cameraFalloff = 1- pow(1-cameraFalloff,2);
                  cameraFalloff = cameraFalloff * _DarkenViewTangent + ( 1 - _DarkenViewTangent);      
                  
                  float deniedRegion = 1;
                  deniedRegion = deniedRegion * ( 1 - cellSpecularFalloff ) ;
                  deniedRegion = deniedRegion * ( 1 - phongSpecularFalloff ) ;
                  
                  cameraFalloff = max( cameraFalloff , (1 - deniedRegion) );    
                }

                // ---------------- Ambient Light
                float3 ambientLight = _AmbientLight;
                float ambientFalloff = 1.0;
                
                if ( rawDiffuseFalloff < CS_AFO_dark_input_limit) {
                  ambientFalloff = CS_AFO_dark_output_value;
                }
                else if( rawDiffuseFalloff < CS_AFO_penumbra_input_upperbound ) {
                  ambientFalloff = remap(CS_AFO_penumbra_input_lowerbound, CS_AFO_penumbra_input_upperbound, CS_AFO_penumbra_output_lowerbound, CS_AFO_penumbra_output_upperbound, rawDiffuseFalloff);
                }
                else {
                  ambientFalloff = 1.0;
                }
                
                ambientLight = ambientLight *  ambientFalloff;

                // ---------------- Composition
                
                // Light Composition
                float3 compositeLight = directDiffuse + ambientLight;
                compositeLight = saturate(compositeLight);
                
                // Surface Composition
                float3 surfaceColor = _ObjectColor * compositeLight;
                surfaceColor = surfaceColor + phongDirectSpecular + cellDirectSpecular;
                
                surfaceColor = surfaceColor * cameraFalloff;
                
                return float4(surfaceColor, 0);
            }
            ENDCG
        }
    }
}