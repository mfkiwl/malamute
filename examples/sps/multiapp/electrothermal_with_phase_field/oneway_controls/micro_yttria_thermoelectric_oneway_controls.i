#This example uses updated electrochemical phase-field model, which includes
#Y and O vacancies as defect species (intrinsic defects)
#One-way coupling from engineering scale to phase-field
#This includes controls to set solve to false when T < 1200 K
initial_field=10 #from the engineering scale, starting value 10 V/m

[Mesh]
  type = GeneratedMesh
  dim = 2
  nx = 80
  ny = 40
  xmin = 0
  xmax = 80
  ymin = 0
  ymax = 40
  # uniform_refine = 1
[]

[GlobalParams]
  op_num = 2
  var_name_base = gr
  int_width = 4
[]

[Variables]
  [./wvy]
  [../]
  [./wvo]
  [../]
  [./phi]
  [../]
  [./PolycrystalVariables]
  [../]
  [./V]
    # scaling = 1e9
  [../]
  [./dV]
  [../]
[]

[AuxVariables]
  [./bnds]
  [../]
  [./F_loc]
    order = CONSTANT
    family = MONOMIAL
  [../]
  [./negative_V]
  [../]
  [./E_x]
    order = CONSTANT
    family = MONOMIAL
  [../]
  [./E_y]
    order = CONSTANT
    family = MONOMIAL
  [../]
  [./negative_dV]
  [../]
  [./dE_x]
    order = CONSTANT
    family = MONOMIAL
  [../]
  [./dE_y]
    order = CONSTANT
    family = MONOMIAL
  [../]
  [./n_cat_aux]
    order = CONSTANT
    family = MONOMIAL
  [../]
  [./n_an_aux]
    order = CONSTANT
    family = MONOMIAL
  [../]
  [./T]
  [../]
  [./Q_joule]     #Problem units of eV/nm^3/s
    order = CONSTANT
    family = MONOMIAL
  [../]
  [./Q_joule_SI]  #SI units of J/m^3/s
    order = CONSTANT
    family = MONOMIAL
  [../]
[]

[ICs]
  [./phi_IC]
    type = SpecifiedSmoothCircleIC
    variable = phi
    x_positions = '40 40'
    y_positions = '0  40'
    z_positions = '0   0'
    radii = '20 20'
    invalue = 0
    outvalue = 1
  [../]
  [./gr0_IC]
    type = SmoothCircleIC
    variable = gr0
    x1 = 40
    y1 = 0
    z1 = 0
    radius = 20
    invalue = 1
    outvalue = 0
  [../]
  [./gr1_IC]
    type = SmoothCircleIC
    variable = gr1
    x1 = 40
    y1 = 40
    z1 = 0
    radius = 20
    invalue = 1
    outvalue = 0
  [../]
  [./T_IC]
    type = ConstantIC
    variable = T
    value = 1600
  [../]
[]

[BCs]
  [./dV_top]
    type = FunctionDirichletBC
    preset = true
    variable = dV
    boundary = top
    function = top_bc_funct
  [../]
  [./dV_bottom]
    type = DirichletBC
    preset = true
    variable = dV
    boundary = bottom
    value = 0
  [../]
[]

[Functions]
  [./top_bc_funct]
    type = ParsedFunction
    vars = 'L_y E_y' #L_y is the length of the domain in the y-direction
    vals = '40  Ey_in'
    value = 'L_y * E_y * 1e-9' #1e-9 converts from length units of m in engineering scale to nm in phase-field
  [../]
  [./temp_switch]
    type = ParsedFunction
    vars = 'center_temp'
    vals = 'center_temperature'
    value = 'if(center_temp > 1100, 1, 0)'
  [../]
[]

[Controls]
  [solve_on]
    type = BoolFunctionControl
    function = temp_switch
    parameter = '*/*/solve'
    execute_on = 'initial timestep_begin'
  []
[]

[Materials]
  # Free energy coefficients for parabolic curves
  [./ks_cat]
    type = ParsedMaterial
    f_name = ks_cat
    args = 'T'
    constant_names = 'a b Va'
    constant_expressions = '-0.0017 140.44 0.03726'
    function = '(a*T + b) * Va^2'
  [../]
  [./ks_an]
    type = ParsedMaterial #TODO re-fit this for oxygen
    f_name = ks_an
    args = 'T'
    constant_names = 'a b Va'
    constant_expressions = '-0.0017 140.44 0.03726'
    function = '(a*T + b) * Va^2'
  [../]
  [./kv_cat]
    type = ParsedMaterial
    f_name = kv_cat
    material_property_names = 'ks_cat'
    function = '10*ks_cat'
  [../]
  [./kv_an]
    type = ParsedMaterial
    f_name = kv_an
    material_property_names = 'ks_cat'
    function = '10*ks_cat'
  [../]
  # Diffusivity and mobilities
  [./chiDy]
    type = GrandPotentialTensorMaterial
    f_name = chiDy
    diffusivity_name = Dvy
    solid_mobility = L
    void_mobility = Lv
    chi = chi_cat
    surface_energy = 6.24
    c = phi
    T = T
    D0 = 5.9e9
    GBmob0 = 1.60e12
    Q = 4.14
    Em = 4.25
    bulkindex = 1
    gbindex = 1e6
    surfindex = 1e9
  [../]
  [./chiDo]
    type = GrandPotentialTensorMaterial
    f_name = chiDo
    diffusivity_name = Dvo
    solid_mobility = Lo
    void_mobility = Lvo
    chi = chi_an
    surface_energy = 6.24
    c = phi
    T = T
    D0 = 5.9e11
    GBmob0 = 1.60e12
    Q = 4.14
    Em = 4.25
    bulkindex = 1
    gbindex = 1e6
    surfindex = 1e9
  [../]
  # Everything else
  [./ns_y_min]
    type = DerivativeParsedMaterial
    f_name = ns_y_min
    args = 'gr0 gr1 T'
    constant_names =        'Ef_B c_GB   kB          Va_Y'
    constant_expressions =  '4.37 0.1    8.617343e-5 0.03726'
    derivative_order = 2
    function = 'c_B:=exp(-Ef_B/kB/T); bnds:=gr0^2 + gr1^2;
                (c_B + 4.0 * c_GB * (1.0 - bnds)^2) / Va_Y'
  [../]
  [./ns_o_min]
    type = DerivativeParsedMaterial
    f_name = ns_o_min
    args = 'gr0 gr1 T'
    constant_names =        'Ef_B c_GB  kB          Va_O'
    constant_expressions =  '1.25 0.1   8.617343e-5 0.02484'
    derivative_order = 2
    function = 'c_B:=exp(-Ef_B/kB/T); bnds:=gr0^2 + gr1^2;
                (c_B + 4.0 * c_GB * (1.0 - bnds)^2) / Va_O'
  [../]
  [./sintering]
    type = ElectrochemicalSinteringMaterial
    chemical_potentials = 'wvy wvo'
    electric_potential = V
    void_op = phi
    Temperature = T
    surface_energy = 6.24
    grainboundary_energy = 6.24
    solid_energy_coefficients = 'kv_cat kv_cat'
    void_energy_coefficients = 'kv_cat kv_an'
    min_vacancy_concentrations_solid = 'ns_y_min ns_o_min'
    min_vacancy_concentrations_void = '26.837 40.2555'
    defect_charges = '-3 2'
    solid_relative_permittivity = 15
    solid_energy_model = PARABOLIC
  [../]
  [./density_chi_y]
    type = ElectrochemicalDefectMaterial
    chemical_potential = wvy
    void_op = phi
    Temperature = T
    electric_potential = V
    void_density_name = nv_cat
    solid_density_name = ns_cat
    chi_name = chi_cat
    void_energy_coefficient = kv_cat
    solid_energy_coefficient = ks_cat
    min_vacancy_concentration_solid = ns_y_min
    min_vacancy_concentration_void = 26.837
    solid_energy_model = PARABOLIC
    defect_charge = -3
    solid_relative_permittivity = 15
  [../]
  [./density_chi_o]
    type = ElectrochemicalDefectMaterial
    chemical_potential = wvo
    void_op = phi
    Temperature = T
    electric_potential = V
    void_density_name = nv_an
    solid_density_name = ns_an
    chi_name = chi_an
    void_energy_coefficient = kv_an
    solid_energy_coefficient = ks_an
    min_vacancy_concentration_solid = ns_o_min
    min_vacancy_concentration_void = 40.2555
    solid_energy_model = PARABOLIC
    defect_charge = 2
    solid_relative_permittivity = 15
  [../]

  [./permittivity]
    type = DerivativeParsedMaterial
    f_name = permittivity
    args = 'phi'
    material_property_names = 'hs hv'
    constant_names =       'eps_rel_solid   eps_void_over_e'
    constant_expressions = '15              5.52e-2' #eps_void_over_e in 1/V/nm
    derivative_order = 2
    function = '-hs * eps_rel_solid * eps_void_over_e - hv * eps_void_over_e'
  [../]
  [./solid_pre]
    type = DerivativeParsedMaterial
    f_name = solid_pre
    material_property_names = 'hs ns_y_min ns_o_min'
    constant_names =       'Z_cat   Z_an'
    constant_expressions = '-3      2'
    derivative_order = 2
    function = '-hs * (Z_cat * ns_y_min + Z_an * ns_o_min)'
  [../]
  [./void_pre]
    type = DerivativeParsedMaterial
    f_name = void_pre
    material_property_names = 'hv'
    constant_names =       'Z_cat   Z_an nv_y_min nv_o_min'
    constant_expressions = '-3      2    26.837   40.2555'
    derivative_order = 2
    function = '-hv * (Z_cat * nv_y_min + Z_an * nv_o_min)'
  [../]
  [./cat_mu_pre]
    type = DerivativeParsedMaterial
    f_name = cat_mu_pre
    material_property_names = 'hs hv ks_cat kv_cat' #TODO add material properties for these
    constant_names =       'Z_cat'
    constant_expressions = '-3'
    derivative_order = 2
    function = '-hs * Z_cat / ks_cat - hv * Z_cat / kv_cat'
  [../]
  [./an_mu_pre]
    type = DerivativeParsedMaterial
    f_name = an_mu_pre
    material_property_names = 'hs hv ks_an kv_an' #TODO add material properties for these
    constant_names =       'Z_an'
    constant_expressions = '2'
    derivative_order = 2
    function = '-hs * Z_an / ks_an - hv * Z_an / kv_an'
  [../]
  [./cat_V_pre]
    type = DerivativeParsedMaterial
    f_name = cat_V_pre
    material_property_names = 'hs hv ks_cat kv_cat' #TODO add material properties for these
    constant_names =       'Z_cat   v_scale e '
    constant_expressions = '-3      1       1'
    derivative_order = 2
    function = 'hs * Z_cat^2 * e * v_scale / ks_cat + hv * Z_cat^2 * e * v_scale / kv_cat'
  [../]
  [./an_V_pre]
    type = DerivativeParsedMaterial
    f_name = an_V_pre
    material_property_names = 'hs hv ks_an kv_an' #TODO add material properties for these and check sign
    constant_names =       'Z_an    v_scale e '
    constant_expressions = '2       1       1'
    derivative_order = 2
    function = 'hs * Z_an^2 * e * v_scale / ks_an + hv * Z_an^2 * e * v_scale / kv_an'
  [../]
  [./n_cat]
    type = ParsedMaterial
    f_name = n_cat
    material_property_names = 'hs ns_cat hv nv_cat'
    function = '(hs*ns_cat + hv*nv_cat)'
  [../]
  [./n_an]
    type = ParsedMaterial
    f_name = n_an
    material_property_names = 'hs ns_an hv nv_an'
    function = '(hs*ns_an + hv*nv_an)'
  [../]
  [./constants]
    type = GenericConstantMaterial
    prop_names =  'gamma_gb'
    prop_values = '1.0154'
  [../]
  [./conductivity]
    type = DerivativeParsedMaterial
    f_name = conductivity
    args = 'phi T'
    material_property_names = 'hs hv n_cat n_an'
    constant_names =       'kB        D0_O    Em_O  D0_Y  Em_Y  Z_Y Z_O'
    constant_expressions = '8.617e-5  5.9e11  4.25  5.9e9 4.25  3   2'
    derivative_order = 2
    function = '(Z_Y^2 * abs(n_cat) * D0_Y * exp(-Em_Y/kB/T) / kB / T + Z_O^2 * abs(n_an) * D0_O * exp(-Em_O/kB/T) / kB / T)*hs + 1e-3'
    # function = '1'
    outputs = exodus
  [../]
[]

[Modules]
  [./PhaseField]
    [./GrandPotential]
      switching_function_names = 'hv hs'
      anisotropic = 'true true'

      chemical_potentials = 'wvy wvo'
      mobilities = 'chiDy chiDo'
      susceptibilities = 'chi_cat chi_an'
      free_energies_w = 'nv_cat ns_cat nv_an ns_an'

      gamma_gr = gamma_gb
      mobility_name_gr = L
      kappa_gr = kappa
      free_energies_gr = 'omegav omegas'

      additional_ops = 'phi'
      gamma_grxop = gamma
      mobility_name_op = Lv
      kappa_op = kappa
      free_energies_op = 'omegav omegas'
    [../]
  [../]
[]

[Kernels]
  [./Laplace]
    type = MatDiffusion
    variable = V
    diffusivity = permittivity
    args = 'phi'
  [../]
  [./potential_solid_constants]
    type = MaskedBodyForce
    variable = V
    args = 'phi'
    mask = solid_pre
  [../]
  [./potential_void_constants]
    type = MaskedBodyForce
    variable = V
    args = 'phi'
    mask = void_pre
  [../]
  [./potential_cat_mu]
    type = MatReaction
    variable = V
    v = wvy
    mob_name = cat_mu_pre
  [../]
  [./potential_an_mu]
    type = MatReaction
    variable = V
    v = wvo
    mob_name = an_mu_pre
  [../]
  [./potential_cat_V]
    type = MatReaction
    variable = V
    mob_name = cat_V_pre
  [../]
  [./potential_an_V]
    type = MatReaction
    variable = V
    mob_name = an_V_pre
  [../]
  [./Laplace_dV]
    type = MatDiffusion
    variable = dV
    diffusivity = conductivity
    args = 'phi'
  [../]
[]


[AuxKernels]
  [./bnds_aux]
    type = BndsCalcAux
    variable = bnds
    execute_on = 'initial timestep_end'
  [../]
  [./negative_V]
    type = ParsedAux
    variable = negative_V
    args = V
    function = '-V'
  [../]
  [./E_x]
    type = VariableGradientComponent
    variable = E_x
    gradient_variable = negative_V
    component = x
  [../]
  [./E_y]
    type = VariableGradientComponent
    variable = E_y
    gradient_variable = negative_V
    component = y
  [../]
  [./negative_dV]
    type = ParsedAux
    variable = negative_dV
    args = dV
    function = '-dV'
  [../]
  [./dE_x]
    type = VariableGradientComponent
    variable = dE_x
    gradient_variable = negative_dV
    component = x
  [../]
  [./dE_y]
    type = VariableGradientComponent
    variable = dE_y
    gradient_variable = negative_dV
    component = y
  [../]
  [./n_cat_aux]
    type = MaterialRealAux
    variable = n_cat_aux
    property = n_cat
  [../]
  [./n_an_aux]
    type = MaterialRealAux
    variable = n_an_aux
    property = n_an
  [../]
  [./Q_joule_aux]
    type = JouleHeatingHeatGeneratedAux
    variable = Q_joule
    electrical_conductivity = conductivity
    elec = dV
  [../]
  [./Q_joule_convert_SI]
    type = ParsedAux
    args = 'Q_joule'
    function = 'Q_joule * 1.602e8'
    variable = Q_joule_SI
  [../]
[]

[Postprocessors]
  [./memory]
    type = MemoryUsage
    outputs = csv
  [../]
  [./n_DOFs]
    type = NumDOFs
    outputs = csv
  [../]
  [./dt]
    type = TimestepSize
  [../]
  [./ns_cat_total]
    type = ElementIntegralMaterialProperty
    mat_prop = n_cat
  [../]
  [./ns_an_total]
    type = ElementIntegralMaterialProperty
    mat_prop = n_an
  [../]
  [./void_tracker]
    type = FeatureFloodCount
    execute_on = 'initial timestep_end'
    variable = phi
    threshold = 0.5
    compute_var_to_feature_map = true
  [../]
  [./Q_joule_total]
    type = ElementIntegralVariablePostprocessor
    variable = Q_joule_SI
  [../]
  [Ey_in]
    type = Receiver
    default = ${initial_field}
  []
  [center_temperature]
    type = PointValue
    variable = T
    point = '40 20 0'
  []
[]

# [VectorPostprocessors]
#   [./neck]
#     type = LineValueSampler
#     start_point = '40 0 0'
#     end_point = '40 40 0'
#     num_points = 41
#     variable = 'gr0 gr1 phi V n_cat_aux n_an_aux'
#     sort_by = y
#   [../]
# []

[Preconditioning]
  [./SMP]
    type = SMP
    full = true
  [../]
[]

[Executioner]
  type = Transient
  scheme = bdf2
  solve_type = PJFNK
  petsc_options_iname = '-pc_type -sub_pc_type -pc_asm_overlap -ksp_gmres_restart -sub_ksp_type'
  petsc_options_value = ' asm      lu           1               31                 preonly'
  nl_max_its = 40
  l_max_its = 30
  l_tol = 1e-4
  nl_rel_tol = 1e-8
  nl_abs_tol = 4e-9
  start_time = 0
  end_time = 2400
  # num_steps = 1
  automatic_scaling = true
  [./TimeStepper]
    type = IterationAdaptiveDT
    dt = 0.1
    optimal_iterations = 8
    iteration_window = 2
  [../]
  # dtmax = 1e4
  # [./Adaptivity]
  #   refine_fraction = 0.8
  #   coarsen_fraction = 0.2
  #   max_h_level = 2
  #   initial_adaptivity = 1
  # [../]
[]

[Debug]
  show_var_residual_norms = true
[]

[Outputs]
  perf_graph = true
  csv = true
  exodus = true
  checkpoint = true

[]